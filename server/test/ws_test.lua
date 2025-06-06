-- ws_test.lua
local log_debug = logger.debug

local WSClient  = import("network/ws_client.lua")
local WSServer  = import("network/ws_server.lua")

local timer_mgr = quanta.get("timer_mgr")
local event_mgr = quanta.get("event_mgr")

local WST = class()

function WST:listen()
    self.server = WSServer()
    self.server:listen("0.0.0.0", 8191)

    event_mgr:add_listener(self, "on_socket_cmd")
    event_mgr:add_listener(self, "on_socket_accept")
    event_mgr:add_listener(self, "on_socket_error", "on_client_error")
end

function WST:connect()
    self.client = WSClient(self)
    self.client:connect("127.0.0.1:8191")
end

function WST:send(msg)
    self.client:send(msg)
end

function WST:on_socket_connect(session, token)
    log_debug("[WST][on_socket_connect]: {}", token)
end

function WST:on_socket_recv(session, msg)
    log_debug("[WST][on_socket_recv]: {}", msg)
end

function WST:on_socket_error(session, token, err)
    log_debug("[WST][on_socket_error]: {}, {}", token, err)
end

function WST:on_socket_accept(session)
    log_debug("[WST][on_socket_accept]: {}", session.token)
end

function WST:on_socket_cmd(session, msg)
    log_debug("[WST][on_socket_cmd]: {}-{}", session.token, msg)
    self.server:send(session, msg)
end

function WST:on_client_error(session, token, err)
    log_debug("[WST][on_client_error]: {}, {}", token, err)
end

timer_mgr:once(1000, function()
    if quanta.index == 1 then
        local wst = WST()
        wst:listen()
        quanta.wst = wst
    end
    if quanta.index == 2 then
        local wst = WST()
        wst:connect()
        quanta.wst = wst
        timer_mgr:loop(1000, function()
            wst:send("hello world")
        end)
    end
end)