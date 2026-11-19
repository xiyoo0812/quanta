-- socket_test.lua
local json          = require("ljson")

local log_debug     = logger.debug
local jsoncodec     = json.jsoncodec

local thread_mgr    = quanta.get("thread_mgr")

local Socket        = import("driver/socket.lua")

local SocketObj = class()
function SocketObj:__init(name, server)
    self.codec = jsoncodec()
    self.server = server
    self.name = name
    if server then
        self.clients = {}
    end
end

function SocketObj:on_socket_accept(socket, token)
    log_debug("socket {} accept socket token: {}", self.name, token)
    socket:set_codec(self.codec)
    self.clients[token] = socket
end

function SocketObj:on_socket_recv(socket, data)
    log_debug("socket {} recv: {}", self.name, data)
    local index = data.index + 1
    thread_mgr:sleep(1000)
    if self.server then
        socket:send_data({ msg = "i am server!", index = index })
        return
    end
    if index > 10 then
        socket:close()
    else
        socket:send_data({ msg = "i am client!", index = index })
    end
end

function SocketObj:on_socket_error(socket, token, err)
    log_debug("socket {} token {} error: {}", self.name, token, err)
    if self.clients then
        self.clients[token] = nil
    end
end

local function test_server()
    thread_mgr:fork(function()
        local socket_obj = SocketObj("socket-svr", true)
        local sock = Socket(socket_obj)
        local ok, err = sock:listen("127.0.0.1", 8700)
        log_debug("socket-svr listen: {}, err: {}", ok, err)
        while true do
            thread_mgr:sleep(100)
        end
    end)
end

local function test_client()
    thread_mgr:fork(function()
        local socket_obj = SocketObj("socket-cli", false)
        local sock = Socket(socket_obj)
        local ok, err = sock:connect("127.0.0.1", 8700)
        log_debug("socket-cli connect: {}, err: {}", ok, err)
        sock:set_codec(jsoncodec())
        sock:send_data({ msg = "i am client!", index = 0 })
        while true do
            thread_mgr:sleep(100)
        end
    end)
end

test_server()
test_client()
