-- kcp_test.lua
require "luakcp"

local log_debug = logger.debug

local KcpClient = import("network/kcp_client.lua")
local KcpServer = import("network/kcp_server.lua")

local timer_mgr = quanta.get("timer_mgr")
local event_mgr = quanta.get("event_mgr")

local KcpTest = class()

function KcpTest:listen()
    self.server = KcpServer()
    self.server:listen("0.0.0.0", 8282)

    event_mgr:add_listener(self, "on_socket_cmd")
    event_mgr:add_listener(self, "on_socket_accept")
    event_mgr:add_listener(self, "on_socket_error", "on_client_error")
end

function KcpTest:connect()
    self.client = KcpClient(self, "127.0.0.1", 8282)
    self.client:connect()
end

function KcpTest:call(cmd_id, msg)
    return self.client:call(cmd_id, msg)
end

function KcpTest:on_socket_recv(session, msg)
    log_debug("[KcpTest][on_socket_recv]: {}", msg)
end

function KcpTest:on_socket_error(session, token, err)
    log_debug("[KcpTest][on_socket_error]: {}, {}", token, err)
end

function KcpTest:on_socket_accept(session)
    log_debug("[KcpTest][on_socket_accept]: {}", session.token)
end

function KcpTest:on_socket_cmd(socket, typ, cmd, cbody, session_id)
    log_debug("[KcpTest][on_socket_cmd]: {}-{}-{}-{}", socket.token, cmd, cbody, session_id)
    cbody.error_code = 0
    cbody.serial = cbody.serial + 1
    self.server:callback_by_id(socket, cmd, cbody, session_id)
end

function KcpTest:on_client_error(session, token, err)
    log_debug("[KcpTest][on_client_error]: {}, {}", token, err)
end

timer_mgr:once(1000, function()
    if quanta.index == 1 then
        local wst = KcpTest()
        wst:listen()
        quanta.wst = wst
    end
    if quanta.index == 2 then
        local wst = KcpTest()
        wst:connect()
        quanta.wst = wst
        local serial = 0
        timer_mgr:loop(3000, function()
            local ok, res = wst:call("NID_HEARTBEAT_REQ", { serial = serial, time = quanta.now })
            log_debug("[KcpTest][NID_HEARTBEAT_REQ]: {}, {}", ok, res)
            if ok then
                serial = res.serial + 1
            end
        end)
    end
end)