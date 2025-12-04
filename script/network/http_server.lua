--http_server.lua
local Socket        = import("driver/socket.lua")

local type          = type
local pcall         = pcall
local log_err       = logger.err
local log_warn      = logger.warn
local log_info      = logger.info
local log_debug     = logger.debug
local tunpack       = table.unpack
local signalquit    = signal.quit
local saddr         = qstring.addr
local jsoncodec     = json.jsoncodec
local httpdcodec    = codec.httpdcodec
local content_codec = codec.set_content_codec
local derive_port   = luabus.derive_port

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")

local HttpServer = class()
local prop = property(HttpServer)
prop:reader("ip", nil)              --http server地址
prop:reader("port", 8080)           --http server端口
prop:reader("jcodec", nil)          --codec
prop:reader("listener", nil)        --网络连接对象
prop:reader("clients", {})          --clients
prop:reader("handlers", {})         --handlers

function HttpServer:__init(http_addr)
    self.jcodec = jsoncodec()
    self.handlers = { GET = {}, POST = {}, PUT = {}, DELETE = {} }
    self:setup(http_addr)
    --注册退出
    update_mgr:attach_quit(self)
end

function HttpServer:on_quit()
    if self.listener then
        self.listener:close()
        log_info("[HttpServer][on_quit]")
    end
end

function HttpServer:setup(http_addr)
    local socket = Socket(self)
    local ip, port = saddr(http_addr)
    local real_port = derive_port(port, ip)
    if not socket:listen(ip, real_port) then
        log_err("[HttpServer][setup] now listen {}:{} failed", ip, real_port)
        signalquit(1)
        return
    end
    self.ip, self.port = ip, real_port
    log_info("[HttpServer][setup] listen({}:{}) success!", self.ip, self.port)
    self.listener = socket
end

function HttpServer:close(token, socket)
    self.clients[token] = nil
    socket:close()
end

function HttpServer:on_socket_error(socket, token, err)
    if socket == self.listener then
        log_info("[HttpServer][on_socket_error] listener({}:{}) close!", self.ip, self.port)
        self.listener = nil
        return
    end
    log_debug("[HttpServer][on_socket_error] client(token:{}) close({})!", token, err)
    self.clients[token] = nil
end

function HttpServer:on_socket_accept(socket, token)
    --log_debug("[HttpServer][on_socket_accept] client(token:{}) connected!", token)
    local hdcodec = httpdcodec()
    content_codec(hdcodec, "application/json", self.jcodec)
    socket:set_codec(hdcodec)
    self.clients[token] = socket
end

function HttpServer:on_socket_recv(socket, method, url, params, headers, body)
    --log_debug("[HttpServer][on_socket_recv] recv: {}, {}, {}, {}, {}!", method, url, params, headers, body)
    local handlers = self.handlers[method]
    if not handlers then
        self:response(socket, 404, "this http method hasn't suppert!")
        return
    end
    self:on_http_request(handlers, socket, url, body, params, headers)
end

--注册get回调
function HttpServer:register_get(url, handler, target)
    log_debug("[HttpServer][register_get] url: {}", url)
    self.handlers.GET[url] = { handler, target }
end

--注册post回调
function HttpServer:register_post(url, handler, target)
    log_debug("[HttpServer][register_post] url: {}", url)
    self.handlers.POST[url] = { handler, target }
end

--注册put回调
function HttpServer:register_put(url, handler, target)
    log_debug("[HttpServer][register_put] url: {}", url)
    self.handlers.PUT[url] = { handler, target }
end

--注册del回调
function HttpServer:register_del(url, handler, target)
    log_debug("[HttpServer][register_del] url: {}", url)
    self.handlers.DELETE[url] = { handler, target }
end

--http post 回调
function HttpServer:on_http_request(handlers, socket, url, ...)
    local handler_info = handlers[url] or handlers["*"]
    if handler_info then
        local handler, target = tunpack(handler_info)
        if not target then
            if type(handler) == "function" then
                local ok, response, headers = pcall(handler, url, ...)
                if not ok then
                    response = { code = 1, msg = response }
                end
                self:response(socket, 200, response, headers)
                return
            end
        else
            if type(handler) == "string" then
                handler = target[handler]
            end
            if type(handler) == "function" then
                local ok, response, headers = pcall(handler, target, url, ...)
                if not ok then
                    log_err("[HttpServer][on_http_request] ok:{}, response:{}", ok, response)
                    response = { code = 1, msg = response }
                end
                self:response(socket, 200, response, headers)
                return
            end
        end
    end
    log_warn("[HttpServer][on_http_request] request {} hasn't process!", url)
    self:response(socket, 404, "this http request hasn't process!")
end

function HttpServer:response(socket, status, response, headers)
    local token = socket:get_token()
    if not token or not response then
        return
    end
    if not headers then
        headers = { ["Content-Type"] = "application/json" }
    end
    if type(response) == "string" then
        local html = response:find("<html")
        headers["Content-Type"] = html and "text/html" or "text/plain"
    end
    socket:send_data(status, headers, response)
    --下一帧关闭
    event_mgr:fire_frame(function()
        self:close(token, socket)
    end)
end

--取消url
function HttpServer:unregister(url)
    self.handlers.GET[url] = nil
    self.handlers.PUT[url] = nil
    self.handlers.POST[url] = nil
    self.handlers.DELETE[url] = nil
end

return HttpServer
