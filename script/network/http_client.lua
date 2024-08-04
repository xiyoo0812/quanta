--httpClient.lua
local Socket        = import("driver/socket.lua")

local pairs         = pairs
local busdns        = luabus.dns
local log_err       = logger.err
local log_debug     = logger.debug
local tconcat       = table.concat
local tunpack       = table.unpack
local trandomarr    = qtable.random_array
local qsurl         = qstring.url
local sformat       = string.format
local jsoncodec     = json.jsoncodec
local httpccodec    = codec.httpccodec
local luencode      = codec.url_encode
local tlscodec      = ssl.tlscodec

local thread_mgr    = quanta.get("thread_mgr")
local update_mgr    = quanta.get("update_mgr")
local HTTP_TIMEOUT  = quanta.enum("NetwkTime", "HTTP_CALL_TIMEOUT")

local proto_text    = luabus.eproto_type.text

local HttpClient = singleton()
local prop = property(HttpClient)
prop:reader("hcodec", nil)          --codec
prop:reader("jcodec", nil)          --codec
prop:reader("clients", {})          --clients
prop:reader("domains", {})          --domains

function HttpClient:__init()
    self.jcodec = jsoncodec()
    self.hcodec = httpccodec(self.jcodec)
    --attach_hour
    update_mgr:attach_hour(self)
end

function HttpClient:on_quit()
    self.clients = {}
    self.domains = {}
end

function HttpClient:on_hour()
    self.domains = {}
end

function HttpClient:on_socket_recv(socket, proto, ...)
    if proto == "TLS" then
        return self:on_handshake(socket, ...)
    end
    return self:on_http_recv(socket.token, ...)
end

function HttpClient:on_handshake(socket, codec, message)
    if message then
        socket:send_data(message)
    end
    if codec.isfinish() then
        log_debug("[HttpClient][on_handshake] success!")
        thread_mgr:response(socket.session_id, socket)
    end
end

function HttpClient:on_http_recv(token, status, headers, body)
    local client = self.clients[token]
    if client then
        client:close()
        self.clients[token] = nil
        thread_mgr:response(client.session_id, true, status, body, headers)
    end
end

function HttpClient:on_socket_error(socket, token, err)
    log_debug("[HttpClient][on_socket_error] client(token:{}) close({})!", token, err)
    self.clients[token] = nil
    if socket.session_id then
        thread_mgr:response(socket.session_id, false, err)
    end
end

--构建请求
function HttpClient:send_request(url, timeout, querys, headers, method, datas)
    if not headers then
        headers = {["Accept"] = "*/*" }
    end
    local ipinfo, port, path, proto = self:parse_url(headers, url)
    if not ipinfo then
        log_err("[HttpClient][send_request] failed : {}", port)
        return false, port
    end
    local socket, err = self:init_http_socket(ipinfo, port, proto, headers)
    if not socket then
        return false, err
    end
    if type(datas) == "table" then
        headers["Content-Type"] = "application/json"
    end
    local session_id = thread_mgr:build_session_id()
    local fmt_url = self:format_url(path, querys)
    socket.session_id = session_id
    self.clients[socket.token] = socket
    socket:send_data(fmt_url, method, headers, datas or "")
    return thread_mgr:yield(session_id, url, timeout or HTTP_TIMEOUT)
end

function HttpClient:init_http_socket(ipinfo, port, proto, headers)
    local socket = Socket(self)
    local ip, host = tunpack(ipinfo)
    local ok, cerr = socket:connect(ip, port, proto_text)
    if not ok then
        return nil, cerr
    end
    if proto == "https" then
        local codec = tlscodec(self.hcodec)
        if not codec then
            return nil, "tls codec create failed!"
        end
        codec:init_tls()
        socket:set_codec(codec)
        socket:send_data()
        headers["Host"] = host
        headers["User-Agent"] = "quanta"
        local session_id = thread_mgr:build_session_id()
        socket.session_id = session_id
        return thread_mgr:yield(session_id, host, HTTP_TIMEOUT)
    end
    socket:set_codec(self.hcodec)
    return socket
end

--get接口
function HttpClient:call_get(url, querys, headers, datas, timeout)
    return self:send_request(url, timeout, querys, headers, "GET", datas)
end

--post接口
function HttpClient:call_post(url, datas, headers, querys, timeout)
    return self:send_request(url, timeout, querys, headers, "POST", datas)
end

--put接口
function HttpClient:call_put(url, datas, headers, querys, timeout)
    return self:send_request(url, timeout, querys, headers, "PUT", datas)
end

--del接口
function HttpClient:call_del(url, querys, headers, timeout)
    return self:send_request(url, timeout, querys, headers, "DELETE")
end

function HttpClient:format_url(url, query)
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

function HttpClient:parse_url(headers, url)
    local proto, host, port, path = qsurl(url)
    if not proto then
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
                return ipinfo, port, path, proto
            end
        end
        local ips = busdns(host)
        if not ips or #ips == 0 then
            return nil, "ip addr parse failed!"
        end
        ipinfo = { trandomarr(ips), host }
        self.domains[host] = ipinfo
        return ipinfo, port, path, proto
    end
    return ipinfo, port, path, proto
end

quanta.http_client = HttpClient()

return HttpClient
