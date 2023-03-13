--player.lua
local log_err           = logger.err
local log_info          = logger.info
local log_debug         = logger.debug
local qfailed           = quanta.failed

local router_mgr        = quanta.get("router_mgr")
local client_mgr        = quanta.get("client_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local FRAME_FAILED      = protobuf_mgr:error_code("FRAME_FAILED")

--创建角色数据
local GatePlayer = class()
local prop = property(GatePlayer)
prop:accessor("session", nil)       --session
prop:accessor("open_id", 0)         --open_id
prop:accessor("player_id", 0)       --player_id
prop:accessor("lobby_id", 0)        --大厅id
prop:accessor("gate_services", {})  --转发服务集合

function GatePlayer:__init(session, open_id, player_id)
    self.session = session
    self.open_id = open_id
    self.player_id = player_id
end

--更新服务网关
function GatePlayer:update_gateway(service_type, server_id)
    log_info("[GatePlayer][update_gateway] player(%d) service(%s) server(%s)!", self.player_id, service_type, server_id)
    self.gate_services[service_type] = server_id
end

--通知数据同步
function GatePlayer:notify_sync()
    for _, server_id in pairs(self.gate_services) do
        router_mgr:send_target(server_id, "rpc_player_sync", self.player_id)
    end
end

--通知连接断开
function GatePlayer:notify_disconnect()
    for _, server_id in pairs(self.gate_services) do
        router_mgr:send_target(server_id, "rpc_player_disconnect", self.player_id)
    end
end

--通知心跳
function GatePlayer:notify_heartbeat(session, cmd_id, body, session_id)
    for _, server_id in pairs(self.gate_services) do
        router_mgr:send_target(server_id, "rpc_player_heartbeat", self.player_id)
    end
    local sserial = client_mgr:check_serial(session, body.serial)
    local data_res = { serial = sserial, time = quanta.now_ms }
    client_mgr:callback_by_id(session, cmd_id, data_res, session_id)
end

--发送消息
function GatePlayer:send_message(cmd_id, data)
    client_mgr:send(self.session, cmd_id, data)
    if cmd_id ~= "NID_ENTITY_MOVE_PATH_NTF" then
        log_debug("[Gateway][send_message] player(%s) send message(%s-%s) !", self.player_id, cmd_id, data)
    end
end

--转发消息
function GatePlayer:notify_command(service_type, cmd_id, body, session_id)
    local server_id = self.gate_services[service_type]
    if not server_id then
        log_err("[GatePlayer][notify_command] service(%s) cnot transfor, cmd_id=%s, player=%s", service_type, cmd_id, self.player_id)
        client_mgr:callback_errcode(self.session, cmd_id, FRAME_FAILED, session_id)
        return
    end
    local ok, codeoe, res = router_mgr:call_target(server_id, "rpc_player_command", self.player_id, cmd_id, body)
    if qfailed(codeoe, ok) then
        log_err("[GatePlayer][notify_command] player(%s) rpc_player_command(%s) code %s, failed: %s", self.player_id, cmd_id, codeoe, res)
        client_mgr:callback_errcode(self.session, cmd_id, codeoe, session_id)
        return
    end
    if cmd_id ~= 12103 then
        log_debug("[GatePlayer][notify_command] player(%s) response message(%s-%s) !", self.player_id, cmd_id, res)
    end
    client_mgr:callback_by_id(self.session, cmd_id, res, session_id)
end

return GatePlayer
