--httpClient.lua
local Socket        = import("driver/socket.lua")

local pairs         = pairs
local busdns        = luabus.dns
local log_err       = logger.err
local log_debug     = logger.debug
local tconcat       = table.concat
local qsaddr        = qstring.addr
local sformat       = string.format
local sgmatch       = string.gmatch
local jsoncodec     = json.jsoncodec
local httpccodec    = codec.httpccodec
local luencode      = codec.url_encode

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

function HttpClient:on_socket_recv(socket, status, headers, body)
    local token = socket.token
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
end

--构建请求
function HttpClient:send_request(url, timeout, querys, headers, method, datas)
    local host, port = self:parse_url_addr(url)
    if not host then
        log_err("[HttpClient][send_request] failed : {}", port)
        return false, port
    end
    local socket = Socket(self)
    local ok, cerr = socket:connect(host, port, proto_text)
    if not ok then
        return false, cerr
    end
    if not headers then
        headers = {["Content-Type"] = "text/plain" }
    end
    if type(datas) == "table" then
        headers["Content-Type"] = "application/json"
    end
    local fmt_url = self:format_url(url, querys)
    local session_id = thread_mgr:build_session_id()
    socket:set_codec(self.hcodec)
    socket.session_id = session_id
    self.clients[socket.token] = socket
    socket:send_data(fmt_url, method, headers, datas or "")
    return thread_mgr:yield(session_id, url, timeout or HTTP_TIMEOUT)
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

function HttpClient:parse_url_addr(url)
    if not url then
        return nil, "htpp url is empty"
    end
    if url:sub(-1) ~= "/" then
        url = sformat("%s/", url)
    end
    local http, addr = sgmatch(url, "(.+)://([^/]-)/")()
    if not http then
        return nil, "Illegal htpp url"
    end
    local host, port = qsaddr(addr)
    if not port then
        port = http == "https" and 443 or 80
    end
    local ip = self.domains[host]
    if not ip then
        local ips = busdns(host)
        if not ips or #ips == 0 then
            return nil, "ip addr parse failed!"
        end
        ip = ips[1]
        self.domains[host] = ip
    end
    return ip, port
end

quanta.http_client = HttpClient()

return HttpClient
