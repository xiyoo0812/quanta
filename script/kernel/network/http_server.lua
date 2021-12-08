--http_server.lua
local lhttp         = require("lhttp")
local ljson         = require("lcjson")
local Socket        = import("driver/socket.lua")

local type          = type
local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local json_encode   = ljson.encode
local tunpack       = table.unpack
local signalquit    = signal.quit
local ssplit        = string_ext.split

local thread_mgr    = quanta.get("thread_mgr")

local HttpServer = class()
local prop = property(HttpServer)
prop:reader("sock", nil)            --网络连接对象
prop:reader("ip", nil)              --http server地址
prop:reader("port", 8080)           --http server端口
prop:reader("clients", {})          --clients
prop:reader("requests", {})         --requests
prop:reader("get_handler", nil)     --get_handler
prop:reader("put_handler", nil)     --put_handler
prop:reader("del_handler", nil)     --del_handler
prop:reader("post_handler", nil)    --post_handler

function HttpServer:__init()
end

function HttpServer:setup(http_addr, post_handler, get_handler)
    self.ip, self.port = tunpack(ssplit(http_addr, ":"))
    local socket = Socket(self)
    if not socket:listen(self.ip, self.port) then
        log_info("[HttpServer][setup] now listen %s failed", http_addr)
        signalquit(1)
        return
    end
    log_info("[HttpServer][setup] listen(%s:%s) success!", self.ip, self.port)
    self.post_handler = post_handler
    self.get_handler = get_handler
    self.sock = socket
end

function HttpServer:on_socket_error(socket, token, err)
    if socket == self.sock then
        log_info("[HttpServer][on_socket_error] listener(%s:%s) close!", self.ip, self.port)
        self.sock = nil
        return
    end
    log_debug("[HttpServer][on_socket_error] client(token:%s) close!", token)
    self.clients[token] = nil
    self.requests[token] = nil
end

function HttpServer:on_socket_accept(socket, token)
    log_debug("[HttpServer][on_socket_accept] client(token:%s) connected!", token)
    self.clients[token] = socket
end

function HttpServer:on_socket_recv(socket, token)
    local request = self.requests[token]
    if not request then
        request = lhttp.create_request()
        log_debug("[HttpServer][on_socket_accept] create_request(token:%s)!", token)
        self.requests[token] = request
    end
    local buf = socket:get_recvbuf()
    if #buf == 0 or not request:append(buf) then
        log_err("[HttpServer][on_socket_recv] http request append failed, close client(token:%s)!", token)
        self:response(socket, request, "this http request parse error!")
        return
    end
    socket:pop(#buf)
    request:process()
    local state = request:state()
    local HTTP_REQUEST_ERROR = 2
    if state == HTTP_REQUEST_ERROR then
        log_err("[HttpServer][on_socket_recv] http request process failed, close client(token:%s)!", token)
        self:response(socket, request, "this http request parse error!")
        return
    end
    local url = request:url()
    local method = request:method()
    local headers = request:headers()
    if self.get_handler and method == "GET" then
        thread_mgr:fork(function()
            local querys = request:querys()
            local hresponse = self.get_handler(url, querys, headers)
            self:response(socket, request, hresponse)
        end)
        return
    end
    if self.post_handler and method == "POST" then
        thread_mgr:fork(function()
            local body = request:body()
            local hresponse = self.post_handler(url, body, headers)
            self:response(socket, request, hresponse)
        end)
        return
    end
    if self.put_handler and method == "PUT" then
        thread_mgr:fork(function()
            local body = request:body()
            local hresponse = self.put_handler(url, body, headers)
            self:response(socket, request, hresponse)
        end)
        return
    end
    if self.del_handler and method == "DELETE" then
        thread_mgr:fork(function()
            local querys = request:querys()
            local hresponse = self.del_handler(url, querys, headers)
            self:response(socket, request, hresponse)
        end)
        return
    end
    log_info("[HttpServer][on_socket_recv] http request no process, close client(token:%s)!", token)
    self:response(socket, request, "this http request has not match!")
end


function HttpServer:response(socket, request, hresponse)
    self.requests[socket:get_token()] = nil
    if type(hresponse) == "userdata" then
        socket:send(hresponse:respond())
        socket:close(false)
        return
    end
    local ttype = "text/plain"
    if type(hresponse) == "table" then
        hresponse = json_encode(hresponse)
        ttype = "application/json"
    end
    socket:send(request:response(200, ttype, hresponse or ""))
    socket:close(false)
end

return HttpServer
