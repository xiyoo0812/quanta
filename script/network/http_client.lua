--http_client.lua

local pairs         = pairs
local busdns        = luabus.dns
local log_err       = logger.err
local log_debug     = logger.debug
local tconcat       = table.concat
local tcopy         = table.copy
local trandomarr    = qtable.random_array
local qsurl         = qstring.url
local sformat       = string.format
local jsoncodec     = json.jsoncodec
local luencode      = codec.url_encode

local HTTP_2        = "h2"
local HTTP_1_1      = "http/1.1"

local update_mgr    = quanta.get("update_mgr")

local Socketls      = import("driver/socketls.lua")
local SocketH2      = import("driver/socketh2.lua")

local HttpClient = class()
local prop = property(HttpClient)
prop:reader("jcodec", nil)  --codec
prop:reader("clients", {})  --clients
prop:reader("domains", {})  --domains
prop:reader("version", nil) --version

function HttpClient:__init(version)
    self.jcodec = jsoncodec()
    self.version = version or HTTP_1_1
    update_mgr:attach_quit(self)
end

function HttpClient:on_quit()
    for _, socket in pairs(self.clients) do
        socket:close()
    end
    self.clients = {}
    self.domains = {}
end

function HttpClient:on_socket_recv(socket, ...)
    log_debug("[HttpClient][on_socket_recv] client(token:{}) args({})!", socket.token, { ... })
end

function HttpClient:on_socket_error(socket, token, err)
    log_debug("[HttpClient][on_socket_error] client(token:{}) close({})!", token, err)
    if self.version == HTTP_2 then
        self.clients[socket.name] = nil
    end
end

--构建请求
function HttpClient:send_request(url, timeout, querys, headers, method, datas)
    local host, ip, port, path, scheme = self:parse_url(url)
    if not host then
        log_err("[HttpClient][send_request] failed : {}", port)
        return false, ip
    end
    local socket, err = self:connect(host, ip, port, scheme, timeout)
    if not socket then
        log_err("[HttpClient][connect] failed : {}", err)
        return false, err
    end
    local ori_headers = {
        ["Host"] = host,
        ["Accept"] = "*/*",
        ["User-Agent"] = "quanta"
    }
    tcopy(headers, ori_headers)
    if type(datas) == "table" then
        ori_headers["Content-Type"] = "application/json"
    end
    local _<close> = quanta.defer(function()
        if self.version == HTTP_1_1 then
            socket:close()
        end
    end)
    local fmt_url = self:format_url(path, querys)
    return socket:send_packet(fmt_url, method, ori_headers, datas or "")
end

function HttpClient:connect(host, ip, port, scheme, timeout)
    local socket
    if self.version == HTTP_2 then
        socket = self.clients[host]
        if not socket then
            socket = SocketH2(self)
            self.clients[host] = socket
            socket.name = host
        end
    else
        socket = Socketls(self)
        if scheme == "http" then
            socket:set_tls_enable(false)
        end
    end
    local ok, cerr = socket:connect(ip, port, timeout)
    if not ok then
        return nil, cerr
    end
    socket:set_content_codec("application/json", self.jcodec)
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

function HttpClient:parse_url(url)
    local scheme, host, port, path = qsurl(url)
    if not scheme then
        return nil, "Illegal htpp url"
    end
    local ip = self.domains[host]
    if not ip then
        if host:sub(1, 3) ~= "www" then
            --尝试 + www
            local nhost = sformat("www.%s", host)
            local ips = busdns(nhost)
            if ips and #ips > 0 then
                ip = trandomarr(ips)
                self.domains[host] = ip
                return host, ip, port, path, scheme
            end
        end
        local ips = busdns(host)
        if not ips or #ips == 0 then
            return nil, "ip addr parse failed!"
        end
        ip = trandomarr(ips)
        self.domains[host] = ip
    end
    return host, ip, port, path, scheme
end

return HttpClient
