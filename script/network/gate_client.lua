--gate_client.lua

local log_err       = logger.err
local log_info      = logger.info
local lnext_id      = luakit.next_id
local sname2sid     = service.name2sid

local FLAG_REQ      = luabus.proto_flag.REQ
local SERVICE       = luabus.relay_type.SERVICE

local event_mgr     = quanta.get("event_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_5_MS   = quanta.enum("PeriodTime", "SECOND_5_MS")

local TcpClient     = import("network/tcp_client.lua")

local GateClient = class(TcpClient)
local prop = property(GateClient)
prop:reader("verify_code", nil)
prop:reader("client_id", nil)
prop:reader("server_id", nil)

function GateClient:__init(ip, port, client_id, server_id, verify_code)
    self.verify_code = verify_code
    self.client_id = client_id
    self.server_id = server_id
    -- cs协议监听
    protobuf_mgr:register(self, "NID_GATE_VERIFY_CODE_NTF", "on_verify_code_ntf")
    -- 开始连接
    self:start()
end

function GateClient:on_socket_connected(socket)
    self.alive = true
    local data = {
        client_id = self.client_id,
        server_id = self.server_id,
        verify_code = self.verify_code
    }
    local ok, res = self:call("NID_GATE_BIND_CLIENT_REQ", data)
    if not ok or res.error_code ~= 0 then
        log_err("[GateClient][on_socket_connected] bind gateway failed: {}", res)
        self:close()
        return false
    end
    log_info("[GateClient][on_socket_connected] bind gateway  success")
    self.timer:change_period(SECOND_5_MS)
    event_mgr:notify_trigger("on_gate_connected")
    return true
end

function GateClient:on_socket_error(token, err)
    TcpClient.on_socket_error(self, token, err)
    self.timer:change_period(SECOND_MS)
end

function GateClient:send_lobby(cmd_id, data)
    return self:output(cmd_id, data, SERVICE, 0, FLAG_REQ, sname2sid("lobby"))
end

function GateClient:call_lobby(cmd_id, data)
    local session_id = lnext_id() & 0xffff
    return self:output(cmd_id, data, SERVICE, session_id, FLAG_REQ, sname2sid("lobby"))
end

function GateClient:on_verify_code_ntf(session, message, body)
    self.verify_code = body.verify_code
end

return GateClient
