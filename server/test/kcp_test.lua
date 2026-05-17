-- kcp_test.lua
require "luakcp"

local log_debug     = logger.debug

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local KcpClient     = import("network/kcp_client.lua")
local KcpServer     = import("network/kcp_server.lua")

local KcpTest = class()

function KcpTest:listen()
    self.server = KcpServer()
    self.server:listen("0.0.0.0", 8282)

    event_mgr:add_listener(self, "on_socket_accept")
    event_mgr:add_listener(self, "on_socket_error")
    protobuf_mgr:register(self, "NID_HEARTBEAT_REQ", "on_heartbeat_req")
end

function KcpTest:connect()
    self.client = KcpClient("127.0.0.1", 8282)
    return self.client:connect()
end

function KcpTest:call(cmd_id, msg)
    return self.client:call(cmd_id, msg)
end

function KcpTest:on_socket_accept(session)
    log_debug("[KcpTest][on_socket_accept] {} connected!", session.token)
end

function KcpTest:on_socket_error(token, err)
    log_debug("[KcpTest][on_socket_error] session: {} lost, because: {}!", token, err)
end

function KcpTest:on_heartbeat_req(session, message, body, response)
    log_debug("[KcpTest][on_heartbeat_req] {} heartbeat req: {}", session.token, body)
    response.time = quanta.now_ms
    response.serial = body.serial + 1
end

local function test_server()
    thread_mgr:fork(function()
        local server = KcpTest()
        server:listen()
        quanta.server = server
    end)
end

local function test_client()
    thread_mgr:fork(function()
        local client = KcpTest()
        if not client:connect() then
            return
        end
        local serial = 0
        while true do
            thread_mgr:sleep(1000)
            local ok, res = client:call("NID_HEARTBEAT_REQ", { serial = serial, time = quanta.now_ms })
            log_debug("[KcpTest][NID_HEARTBEAT_REQ]: {}, {}", ok, res)
            if ok then
                serial = res.serial + 1
            end
        end
    end)
end

if quanta.index == 1 then
    test_server()
end
if quanta.index == 2 then
    test_client()
end
