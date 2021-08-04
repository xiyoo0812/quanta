--http_server.lua
import("driver/poll.lua")
local lhttp         = require("lhttp")
local ljson         = require("lcjson")
local Socket        = import("driver/socket.lua")

local type          = type
local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local serialize     = logger.serialize
local json_encode   = ljson.encode
local tunpack       = table.unpack
local ssplit        = string_ext.split

local poll          = quanta.get("poll")
local thread_mgr    = quanta.get("thread_mgr")

local HttpServer = class()
local prop = property(HttpServer)
prop:reader("sock", nil)    --网络连接对象
prop:reader("ip", nil)      --http server地址
prop:reader("port", 27017)  --http server端口
prop:reader("clients", {})  --clients
prop:reader("requests", {}) --requests
prop:reader("get_handler", nil)  --get_handler
prop:reader("post_handler", nil) --post_handler

function HttpServer:__init()
    ljson.encode_sparse_array(true)
end

function HttpServer:setup(http_addr, post_handler, get_handler)
    self.ip, self.port = tunpack(ssplit(http_addr, ":"))
    local sock = Socket(poll, self)
    if not sock:listen(self.ip, self.port) then
        log_info("[HttpServer][setup] now listen %s failed", http_addr)
        os.exit(1)
        return
    end
    log_info("[HttpServer][setup] listen(%s:%s) success!", self.ip, self.port)
    self.post_handler = post_handler
    self.get_handler = get_handler
    self.sock = socket
end

function HttpServer:on_socket_close(socket, fd)
    if socket == self.sock then
        log_info("[HttpServer][on_socket_close] listener(%s:%s) close!", self.ip, self.port)
        self.sock = nil
        return
    end
    log_debug("[HttpServer][on_socket_close] client(fd:%s) close!", fd)
    self.clients[fd] = nil
    local request = self.requests[fd]
    if request then
        request:close()
        self.requests[fd] = nil
    end
end

function HttpServer:process_query(headers, query_str)
    if #query_str > 0 then
        local fmt_querys = ssplit(query_str, "&")
        for _, fmtq in pairs(fmt_querys) do
            local query = ssplit(fmtq, "=")
            if #query == 2 then
                headers[query[1]] = query[2]
            end
        end
    end
end

function HttpServer:process_params(request)
    local method = request:method()
    local headers = request:headers()
    local target = request:target()
    local url_info = ssplit(target, "?")
    if #url_info == 2 then
        self:process_query(headers, url_info[2])
        return method, url_info[1], headers
    end
    return method, target, headers
end

function HttpServer:on_socket_accept(socket, fd)
    log_debug("[HttpServer][on_socket_accept] client(fd:%s) connected!", fd)
    self.clients[fd] = socket
end

function HttpServer:on_socket_recv(socket, fd)
    local request = self.requests[fd]
    if not request then
        request = lhttp.create_request()
        log_debug("[HttpServer][on_socket_accept] create_request(fd:%s)!", fd)
        self.requests[fd] = request
    end
    local buf = socket:get_recvbuf()
    if #buf == 0 or not request:append(buf) then
        log_err("[HttpServer][on_socket_recv] http request append failed, close client(fd:%s)!", fd)
        self:response(socket, request, "this http request parse error!")
        return
    end
    socket:pop(#buf)
    request:process()
    local state = request:state()
    local HTTP_REQUEST_ERROR = 2
    if state == HTTP_REQUEST_ERROR then
        log_err("[HttpServer][on_socket_recv] http request process failed, close client(fd:%s)!", fd)
        self:response(socket, request, "this http request parse error!")
        return
    end
    local method, url, headers = self:process_params(request)
    if self.get_handler and method == "GET" then
        thread_mgr:fork(function()
            local http_res = self.get_handler(url, headers)
            self:response(socket, request, http_res)
        end)
        return
    end
    if self.post_handler and method == "POST" then
        thread_mgr:fork(function()
            local body = request:body()
            local http_res = self.post_handler(url, body, headers)
            self:response(socket, request, http_res)
        end)
        return
    end
    if method == "PUT" then
        local body = request:body()
        log_info("on_put: %s, %s, %s", url, body, serialize(headers))
    end
    if method == "DELETE" then
        log_info("on_del: %s, %s", url, serialize(headers))
    end
    log_info("[HttpServer][on_socket_recv] http request no process, close client(fd:%s)!", fd)
    self:response(socket, request, "this http request has not match!")
end


function HttpServer:response(socket, request, hrsp)
    local ttype = "text/plain"
    if type(hrsp) == "table" then
        hrsp = json_encode(hrsp)
        ttype = "application/json"
    end
    self.requests[socket:get_fd()] = nil
    local buf = request:response(200, ttype, hrsp or "")
    socket:send(buf)
    socket:close()
end

return HttpServer
