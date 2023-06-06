--player.lua
local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local qfailed       = quanta.failed
local rallocv       = service.rallocv
local rallorl       = service.rallorl()

local group_mgr     = quanta.get("group_mgr")
local router_mgr    = quanta.get("router_mgr")
local client_mgr    = quanta.get("client_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local RAR_HASHKEY   = quanta.enum("RouteAllocRule", "HASHKEY")
local FRAME_FAILED  = protobuf_mgr:error_code("FRAME_FAILED")

--创建角色数据
local GatePlayer = class()
local prop = property(GatePlayer)
prop:reader("open_id", 0)       --open_id
prop:reader("player_id", 0)     --player_id
prop:reader("groups", {})       --分组列表
prop:reader("passkeys", {})     --通行证列表
prop:accessor("token", 0)       --token
prop:accessor("lobby_id", 0)    --大厅id
prop:accessor("session", nil)   --session

function GatePlayer:__init(session, open_id, player_id)
    self.session = session
    self.open_id = open_id
    self.player_id = player_id
end

--更新服务网关
function GatePlayer:update_passkey(service_type, server_id)
    log_info("[GatePlayer][update_passkey] player(%d) service(%s) id(%s)!", self.player_id, service_type, server_id)
    self.passkeys[service_type] = server_id
end

--更新分组信息
function GatePlayer:update_group(group_name, group_id)
    log_info("[GatePlayer][update_group] player(%d) group(%s) id(%s)!", self.player_id, group_name, group_id)
    local old_group = self.groups[group_name]
    self.groups[group_name] = group_id
    --管理 玩家 group 信息
    if old_group and old_group ~= group_id then
        group_mgr:remove_member(old_group, self.player_id)
    end
    if group_id then
        group_mgr:add_member(group_id, self.player_id, self)
    end
end

--通知连接断开
function GatePlayer:notify_disconnect()
    for _, server_id in pairs(self.passkeys) do
        router_mgr:send_target(server_id, "rpc_player_disconnect", self.player_id)
    end
end

--通知心跳
function GatePlayer:notify_heartbeat(session, cmd_id, body, session_id)
    -- 缓存服务
    for _, server_id in pairs(self.passkeys) do
        router_mgr:send_hash(server_id, self.player_id, "rpc_player_heartbeat", self.player_id)
    end
    -- hashkey服务
    for _,service_type in pairs(rallorl[RAR_HASHKEY] or {}) do
        router_mgr:send_hash(service_type, self.player_id, "rpc_player_heartbeat", self.player_id, quanta.id, self.token)
    end
    client_mgr:check_flow(session)
    client_mgr:callback_by_id(session, cmd_id, { time = quanta.now_ms }, session_id)
end

--发送消息
function GatePlayer:send_message(cmd_id, data, display)
    client_mgr:send(self.session, cmd_id, data)
    if display then
        log_debug("[Gateway][send_message] player(%s) send message(%s-%s) !", self.player_id, cmd_id, data)
    end
end

--转发消息
function GatePlayer:notify_command(service_type, cmd_id, body, session_id, display)
    local ok, codeoe, res
    local alloc_type = rallocv(service_type)
    if alloc_type == RAR_HASHKEY then
        local hash_key = body.hash_key or self.player_id
        if not hash_key then
            log_err("[GatePlayer][notify_command] service(%s) cnot transfor not hash_key, cmd_id=%s, player=%s", service_type, cmd_id, self.player_id)
            return
        end
        ok, codeoe, res = router_mgr:call_hash(service_type, hash_key, "rpc_player_command", self.player_id, cmd_id, body, quanta.id, self.token)
    else
        local server_id = self.passkeys[service_type]
        if not server_id then
            log_err("[GatePlayer][notify_command] service(%s) cnot transfor not server_id, cmd_id=%s, player=%s", service_type, cmd_id, self.player_id)
            client_mgr:callback_errcode(self.session, cmd_id, FRAME_FAILED, session_id)
            return
        end
        ok, codeoe, res = router_mgr:hash_call(server_id, self.player_id, "rpc_player_command", self.player_id, cmd_id, body)
    end

    if qfailed(codeoe, ok) then
        log_err("[GatePlayer][notify_command] player(%s) rpc_player_command(%s) code %s, failed: %s", self.player_id, cmd_id, codeoe, res)
        client_mgr:callback_errcode(self.session, cmd_id, codeoe, session_id)
        return
    end
    if display then
        log_debug("[GatePlayer][notify_command] player(%s) response message(%s-%s) !", self.player_id, cmd_id, res)
    end
    client_mgr:callback_by_id(self.session, cmd_id, res, session_id)
end

return GatePlayer
