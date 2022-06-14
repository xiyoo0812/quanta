--player.lua
local log_err           = logger.err
local qfailed           = quanta.failed

local ErrorCode         = ncmd_cs.ErrorCode
local FRAME_FAILED      = ErrorCode.FRAME_FAILED

local router_mgr        = quanta.get("router_mgr")
local client_mgr        = quanta.get("client_mgr")

--创建角色数据
local GatePlayer = class()
local prop = property(GatePlayer)
prop:reader("session", nil)         --session
prop:accessor("user_id", 0)         --user_id
prop:accessor("player_id", 0)       --player_id
prop:accessor("lobby_id", 0)        --大厅id
prop:accessor("gate_services", {})  --转发服务集合

function GatePlayer:__init(session, user_id, player_id)
    self.session = session
    self.user_id = user_id
    self.player_id = player_id
end

--更新服务网关
function GatePlayer:update_gateway(service_type, server_id)
    self.gate_services[service_type] = server_id
end

--通知数据同步
function GatePlayer:notify_sync()
    router_mgr:call_target(self.lobby_id, "rpc_session_sync", self.player_id)
end

--通知连接断开
function GatePlayer:notify_disconnect()
    router_mgr:call_target(self.lobby_id, "rpc_session_error", self.player_id)
end

--转发消息
function GatePlayer:trans_message(server_id, rpc, ...)
    local ok, codeoe, res = router_mgr:call_target(server_id, "rpc", ...)
    return ok and codeoe or FRAME_FAILED, ok and res or codeoe
end

--转发消息
function GatePlayer:notify_command(service_type, cmd_id, body, session_id)
    local server_id = self.gate_services[service_type]
    if not server_id then
        log_err("[GatePlayer][notify_command] service(%s) cnot transfor, cmd_id=%s, player=%s", service, cmd_id, self.player_id)
        client_mgr:callback_errcode(cmd_id, FRAME_FAILED, session_id)
        return
    end
    local codeoe, res = self:trans_message(server_id, "rpc_session_command", self.player_id, cmd_id, body)
    if qfailed(codeoe) then
        log_err("[GatePlayer][notify_command] call rpc_session_command(%s) code %s, failed: %s", cmd_id, codeoe, res)
        client_mgr:callback_errcode(cmd_id, codeoe, session_id)
        return
    end
    client_mgr:callback_by_id(self.session, cmd_id, res, session_id)
end

return GatePlayer
