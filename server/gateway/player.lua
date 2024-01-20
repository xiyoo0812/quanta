--player.lua
local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local qfailed       = quanta.failed

local group_mgr     = quanta.get("group_mgr")
local router_mgr    = quanta.get("router_mgr")
local client_mgr    = quanta.get("client_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local FRAME_FAILED  = protobuf_mgr:error_code("FRAME_FAILED")

--创建角色数据
local GatePlayer = class()
local prop = property(GatePlayer)
prop:reader("open_id", 0)       --open_id
prop:reader("player_id", 0)     --player_id
prop:reader("groups", {})       --分组列表
prop:accessor("token", 0)       --token
prop:accessor("lobby_id", 0)    --大厅id
prop:accessor("session", nil)   --session

function GatePlayer:__init(session, open_id, player_id)
    self.session = session
    self.open_id = open_id
    self.player_id = player_id
end

function GatePlayer:get_session_token()
    return self.session.token
end

--查询组ID
function GatePlayer:get_group_id(group_name)
    return self.groups[group_name]
end

--更新分组信息
function GatePlayer:update_group(group_name, group_id)
    log_info("[GatePlayer][update_group] player({}) group({}) id({})!", self.player_id, group_name, group_id)
    local old_group = self.groups[group_name]
    self.groups[group_name] = group_id
    --管理 玩家 group 信息
    if old_group and old_group ~= group_id then
        group_mgr:remove_member(old_group, self.player_id)
    end
    if group_id > 0 then
        group_mgr:add_member(group_id, self.player_id, self)
    end
end

--通知连接断开
function GatePlayer:notify_disconnect()
    router_mgr:forward_send(self.player_id, -1, "rpc_player_disconnect", self.player_id)
end

--通知心跳
function GatePlayer:notify_heartbeat(session, cmd_id, body, session_id)
    -- 缓存服务
    router_mgr:forward_send(self.player_id, -1, "rpc_player_heartbeat", self.player_id)
    client_mgr:check_flow(session)
    client_mgr:callback_by_id(session, cmd_id, { time = quanta.now_ms, error_code = 0 }, session_id)
end

--发送消息
function GatePlayer:send_message(cmd_id, data, display)
    client_mgr:send(self.session, cmd_id, data)
    if display then
        log_debug("[GatePlayer][send_message] player({}) send message({}-{}) !", self.player_id, cmd_id, data)
    end
end

--转发消息
function GatePlayer:notify_command(service_id, cmd_id, body, session_id, display)
    local pla_id = self.player_id
    local ok, codeoe, res = router_mgr:forward_call(pla_id, service_id, "rpc_player_command", pla_id, cmd_id, body)
    if not ok then
        log_err("[GatePlayer][notify_command] player({}) rpc_player_command({}) failed: {}", pla_id, cmd_id, codeoe)
        return FRAME_FAILED, codeoe
    end
    if qfailed(codeoe, ok) then
        log_err("[GatePlayer][notify_command] player({}) rpc_player_command({}) code {}, failed: {}", pla_id, cmd_id, codeoe, res)
        client_mgr:callback_errcode(self.session, cmd_id, codeoe, session_id)
        return
    end
    if display then
        log_debug("[GatePlayer][notify_command] player({}) response message({}-{}) !", pla_id, cmd_id, res)
    end
    client_mgr:callback_by_id(self.session, cmd_id, res, session_id)
end

return GatePlayer
