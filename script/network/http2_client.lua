--http2_client.lua
local Socket        = import("driver/socket.lua")

local pairs         = pairs
local busdns        = luabus.dns
local log_err       = logger.err
local log_debug     = logger.debug
local tconcat       = table.concat
local tunpack       = table.unpack
local tcopy         = qtable.copy
local trandomarr    = qtable.random_array
local qsurl         = qstring.url
local schar         = string.char
local sformat       = string.format
local jsoncodec     = json.jsoncodec
local http2ccodec   = codec.http2ccodec
local luencode      = codec.url_encode
local tlscodec      = ssl.tlscodec

local thread_mgr    = quanta.get("thread_mgr")
local update_mgr    = quanta.get("update_mgr")
local HTTP_TIMEOUT  = quanta.enum("NetwkTime", "HTTP_CALL_TIMEOUT")

local H2_FRAME      = codec.h2_frame_type
local proto_text    = luabus.eproto_type.text

local ERROR = {
	[0x00] = "Graceful shutdown",
	[0x01] = "Protocol error detected",
	[0x02] = "Implementation fault",
	[0x03] = "Flow-control limits exceeded",
	[0x04] = "Settings not acknowledged",
	[0x05] = "Frame received for closed stream",
	[0x06] = "Frame size incorrect",
	[0x07] = "Stream not processed",
	[0x08] = "Stream cancelled",
	[0x09] = "Compression state not updated",
	[0x0a] = "TCP connection error for CONNECT method",
	[0x0b] = "Processing capacity exceeded",
	[0x0c] = "Negotiated TLS parameters not acceptable",
	[0x0d] = "Use HTTP/1.1 for the request",
}

local Http2Client = singleton()
local prop = property(Http2Client)
prop:reader("hcodec", nil)          --codec
prop:reader("jcodec", nil)          --codec
prop:reader("clients", {})          --clients
prop:reader("domains", {})          --domains
prop:reader("alpn_protos", nil)     --alpn_protos

function Http2Client:__init()
    local alpn_proto = "h2"
    self.jcodec = jsoncodec()
    self.hcodec = http2ccodec(self.jcodec)
    self.alpn_protos = schar(#alpn_proto) .. alpn_proto
    --attach_hour
    update_mgr:attach_hour(self)
end

function Http2Client:on_quit()
    self.clients = {}
    self.domains = {}
end

function Http2Client:on_hour()
    self.domains = {}
end

function Http2Client:on_socket_error(socket, token, err)
    log_debug("[Http2Client][on_socket_error] client(token:{}) close({})!", token, err)
    for _, session_id in pairs(socket.streams) do
        thread_mgr:response(session_id, false, err)
    end
    self.clients[socket.name] = nil
    self.clients[token] = nil
    socket.streams = {}
end

function Http2Client:on_socket_recv(socket, proto, ...)
    if proto == "TLS" then
        return self:on_handshake(socket, ...)
    end
    return self:on_http_recv(socket, socket.token, ...)
end

function Http2Client:on_handshake(socket, codec, message)
    if message then
        socket:send_data(message)
    end
    local ok, alpn = codec.isfinish()
    if ok then
        log_debug("[Http2Client][on_handshake] success! {}", alpn)
        socket:send_data("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
        codec.set_codec(self.hcodec)
        self:send_frame(socket, H2_FRAME.SETTINGS)
    end
end

function Http2Client:on_http_recv(socket, token, streams)
    for _, stream in ipairs(streams) do
        local stream_id = stream[1]
        if stream_id > 0 then
            if stream_id % 2 == 1 then
                local session_id = socket.streams[stream_id]
                if session_id then
                    socket.streams[stream_id] = nil
                    local code, status, body, headers = tunpack(stream, 2)
                    if code > 0 then
                        thread_mgr:response(session_id, false, code, ERROR[code])
                    else
                        thread_mgr:response(session_id, true, status, body, headers)
                    end
                end
            else
                self:on_http_push(socket, token, stream)
            end
        else
            self:on_http_frame(socket, token, stream)
        end
    end
end

--服务器推送
function Http2Client:on_http_push(client, token, stream)
end

--控制帧
function Http2Client:on_http_frame(socket, token, stream)
    local type = stream[2]
    if type == H2_FRAME.SETTINGS then
        local ack, settings = tunpack(stream, 3)
        log_debug("[Http2Client][SETTINGS] client({}) ack({}), settings({})!", token, ack, settings)
        socket.settings = tcopy(settings, socket.settings)
        if ack and socket.session_id then
            thread_mgr:response(socket.session_id, socket)
            socket.session_id = nil
        end
        return
    end
    if type == H2_FRAME.GOAWAY then
        local last_id, code, err = tunpack(stream, 3)
        log_debug("[Http2Client][GOAWAY] client({}) last_id({}), error({}:{})!", token, last_id, code, err)
        self.clients[socket.name] = nil
        self.clients[token] = nil
        socket:close()
        return
    end
    if type == H2_FRAME.WINDOW_UPDATE then
        local winsize = tunpack(stream, 3)
        log_debug("[Http2Client][WINDOW_UPDATE] client({}) winsize({})!", token, winsize)
        socket.winsize = winsize
        return
    end
end

function Http2Client:get_stream_id(socket)
    local stream_id = socket.stream_id
    socket.stream_id = socket.stream_id + 2
    return stream_id
end

--发送控制帧
function Http2Client:send_frame(client, frame, ...)
    log_debug("[Http2Client][send_frame] client(token:{}) frame({})!", client.token, frame)
    client:send_data(0, frame, ...)
end

--构建请求
function Http2Client:send_request(url, timeout, querys, headers, method, datas)
    if not headers then
        headers = {["accept"] = "*/*" }
    end
    local ipinfo, port, path = self:parse_url(url)
    if not ipinfo then
        log_err("[Http2Client][send_request] url {}, failed : {}", url, port)
        return false, port
    end
    local socket, err = self:init_http2_socket(ipinfo, port, headers)
    if not socket then
        return false, err
    end
    if type(datas) == "table" then
        headers["content-type"] = "application/json"
    end
    local session_id = thread_mgr:build_session_id()
    local stream_id = self:get_stream_id(socket)
    local fmt_url = self:format_url(path, querys)
    socket.streams[stream_id] = session_id
    socket:send_data(stream_id, fmt_url, method, headers, datas or "")
    return thread_mgr:yield(session_id, url, timeout or HTTP_TIMEOUT)
end

function Http2Client:init_http2_socket(ipinfo, port, headers)
    local ip, host = tunpack(ipinfo)
    local sock_name = sformat("%s:%s", host, port)
    log_debug("init_http2_socket: {}, {}, {}", ip, host, port)
    local csocket = self.clients[sock_name]
    if csocket then
        if csocket.stream_id < 0x7FFFFFFF then
            return csocket
        end
        -- ​​Stream ID 耗尽时的处理​
        self:send_frame(csocket, H2_FRAME.GOAWAY, 0, 0)
        self.clients[sock_name] = nil
    end
    local socket = Socket(self)
    local ok, cerr = socket:connect(ip, port, proto_text)
    if not ok then
        return nil, cerr
    end
    headers[":authority"] = host
    headers["user-agent"] = "quanta"
    local codec = tlscodec(true, self.alpn_protos)
    if not codec then
        return nil, "tls codec create failed!"
    end
    socket:set_codec(codec)
    socket:send_data()
    socket.streams = {}
    socket.stream_id = 1
    socket.name = sock_name
    socket.session_id = thread_mgr:build_session_id()
    self.clients[socket.name] = socket
    self.clients[socket.token] = socket
    return thread_mgr:yield(socket.session_id, host, HTTP_TIMEOUT)
end

--get接口
function Http2Client:call_get(url, querys, headers, datas, timeout)
    return self:send_request(url, timeout, querys, headers, "GET", datas)
end

--post接口
function Http2Client:call_post(url, datas, headers, querys, timeout)
    return self:send_request(url, timeout, querys, headers, "POST", datas)
end

--put接口
function Http2Client:call_put(url, datas, headers, querys, timeout)
    return self:send_request(url, timeout, querys, headers, "PUT", datas)
end

--del接口
function Http2Client:call_del(url, querys, headers, timeout)
    return self:send_request(url, timeout, querys, headers, "DELETE")
end

function Http2Client:format_url(url, query)
    if query then
        local qtype = type(query)
        if qtype == "string" and #query > 0 then
            return sformat("%s?%s", url, query)
        end
        if qtype == "table" and next(query) then
            local fquery = {}
            for key, value in pairs(query) do
                fquery[#fquery + 1] = sformat("%s=%s", luencode(key), luencode(value))
            end
            return sformat("%s?%s", url, tconcat(fquery, "&"))
        end
    end
    return url
end

function Http2Client:parse_url(url)
    local proto, host, port, path = qsurl(url)
    if not proto or proto ~= "https" then
        return nil, "Illegal htpp url"
    end
    local ipinfo = self.domains[host]
    if not ipinfo then
        if host:sub(1, 3) ~= "www" then
            --尝试 + www
            local nhost = sformat("www.%s", host)
            local ips = busdns(nhost)
            if ips then
                ipinfo = { trandomarr(ips), nhost }
                self.domains[host] = ipinfo
                return ipinfo, port, path
            end
        end
        local ips = busdns(host)
        if not ips or #ips == 0 then
            return nil, "ip addr parse failed!"
        end
        ipinfo = { trandomarr(ips), host }
        self.domains[host] = ipinfo
        return ipinfo, port, path
    end
    return ipinfo, port, path
end

quanta.http2_client = Http2Client()

return Http2Client
