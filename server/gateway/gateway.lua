--gateway.lua
local log_err           = logger.err
local log_info          = logger.info
local log_warn          = logger.warn
local qfailed           = quanta.failed

local event_mgr         = quanta.get("event_mgr")
local client_mgr        = quanta.get("client_mgr")

local service_gate      = service.name2sid("gateway")
local GatePlayer     	= import("gateway/player.lua")

local ErrorCode         = ncmd_cs.ErrorCode
local FRAME_FAILED      = ErrorCode.FRAME_FAILED
local PLAYER_INLINE     = ErrorCode.LOGIN_PLAYER_INLINE

local NCmdId            = ncmd_cs.NCmdId
local HEARTBEAT_REQ     = NCmdId.NID_HEARTBEAT_REQ
local HEARTBEAT_RES     = NCmdId.NID_HEARTBEAT_RES
local ROLE_LOGIN_REQ    = NCmdId.NID_LOGIN_ROLE_LOGIN_REQ
local ROLE_LOGOUT_REQ   = NCmdId.NID_LOGIN_ROLE_LOGOUT_REQ
local ROLE_RELOAD_REQ   = NCmdId.NID_LOGIN_ROLE_RELOAD_REQ
local ROLE_KICKOUT_NTF  = NCmdId.NID_LOGIN_ROLE_KICKOUT_NTF

local Gateway = class()
local prop = property(Gateway)
prop:reader("players", {})          --会话列表

function Gateway:__init(session_type)
    -- 网络事件监听
    event_mgr:add_listener(self, "on_session_cmd")
    event_mgr:add_listener(self, "on_session_sync")
    event_mgr:add_listener(self, "on_session_error")
    -- rpc消息监听
    event_mgr:add_listener(self, "on_update_gateway")
    event_mgr:add_listener(self, "on_kickout_client")
    event_mgr:add_listener(self, "on_forward_client")
    event_mgr:add_listener(self, "on_broadcast_client")
    -- cs协议监听
    event_mgr:add_cmd_listener(self, HEARTBEAT_REQ, "on_heartbeat_req")
    event_mgr:add_cmd_listener(self, ROLE_LOGIN_REQ, "on_role_login_req")
    event_mgr:add_cmd_listener(self, ROLE_LOGOUT_REQ, "on_role_logout_req")
    event_mgr:add_cmd_listener(self, ROLE_RELOAD_REQ, "on_role_reload_req")
end

--查找玩家
function Gateway:get_player(player_id)
    if player_id then
        return self.players[player_id]
    end
    return nil
end

--更新网关信息
function Gateway:on_update_gateway(player_id, service_type, server_id)
    local player = self:get_player(player_id)
    if player then
        player:update_gateway(service_type, server_id)
    end
end

--踢掉客户端
function Gateway:on_kickout_client(player_id, reason)
    local player = self:get_player(player_id)
    if player then
        local session = player:get_session()
        player:send_message(ROLE_KICKOUT_NTF, { reason = reason })
        client_mgr:close_session(session)
        self.players[player_id] = nil
    end
end

--转发给客户端
function Gateway:on_forward_client(player_id, cmd_id, data)
    local player = self:get_player(player_id)
    if player then
        player:send_message(cmd_id, data)
    end
end

--广播给客户端
function Gateway:on_broadcast_client(cmd_id, data)
    client_mgr:broadcast(cmd_id, data)
end

--心跳协议
function Gateway:on_heartbeat_req(session, body, session_id)
    local sserial  = client_mgr:check_serial(session, body.serial)
    local data_res = { serial = sserial, time = quanta.now }
    client_mgr:callback(session, HEARTBEAT_RES, data_res, session_id)
end

--玩家登陆
function Gateway:on_role_login_req(session, body, session_id)
    local user_id, player_id, lobby, token = body.user_id, body.role_id, body.lobby, body.token
    log_info("[Gateway][on_role_login_req] user(%s) player(%s) login start!", user_id, player_id)
    if session.player_id or self:get_player(player_id) then
        return client_mgr:callback_errcode(ROLE_LOGIN_REQ, PLAYER_INLINE, session_id)
    end
    local player = GatePlayer(session, user_id, player_id)
    local codeoe, res = player:trans_message(lobby, "rpc_player_login", user_id, player_id, lobby, token)
    if qfailed(codeoe) then
        log_err("[Gateway][on_role_login_req] call rpc_player_login code %s failed: %s", codeoe, res)
        return client_mgr:callback_errcode(ROLE_LOGIN_REQ, codeoe, session_id)
    end
    for service, server_id in pairs(res) do
        player:update_gateway(service, server_id)
    end
    player:set_lobby_id(lobby)
    session.player_id = player_id
    self.players[player_id] = player
    log_info("[Gateway][on_role_login_req] user(%s) player(%s) login success!", user_id, player_id)
    client_mgr:callback_errcode(ROLE_LOGIN_REQ, codeoe, session_id)
end

--玩家登出
function Gateway:on_role_logout_req(session, body, session_id)
    local user_id, player_id = body.user_id, body.role_id
    log_info("[Gateway][on_role_logout_req] user(%s) player(%s) logout start!", user_id, player_id)
    local player = self:get_player(player_id)
    if player then
        local codeoe, token = player:trans_message(player:get_lobby_id(), "rpc_player_logout", user_id, player_id)
        if qfailed(codeoe) then
            log_err("[Gateway][on_role_logout_req] call rpc_player_logout code %s failed: %s", codeoe, token)
            return client_mgr:callback_errcode(ROLE_LOGOUT_REQ, codeoe, session_id)
        end
        log_info("[Gateway][on_role_logout_req] user(%s) player(%s) logout success!", user_id, player_id)
        local callback_data = { error_code = codeoe, account_token = token}
        client_mgr:callback_by_id(session, ROLE_LOGOUT_REQ, callback_data, session_id)
        client_mgr:close_session(session)
        self.players[player_id] = nil
    end
end

--玩家重登
function Gateway:on_role_reload_req(session, body, session_id)
    local user_id, player_id, lobby, token = body.user_id, body.role_id, body.lobby, body.token
    log_info("[Gateway][on_role_reload_req] user(%s) player(%s) reload start!", user_id, player_id)
    if session.player_id or self:get_player(player_id) then
        return client_mgr:callback_errcode(ROLE_RELOAD_REQ, PLAYER_INLINE, session_id)
    end
    local player = GatePlayer(session, user_id, player_id)
    local codeoe, res = player:trans_message(lobby, "rpc_player_reload", user_id, player_id, lobby, token)
    if qfailed(codeoe) then
        log_err("[Gateway][on_role_reload_req] call rpc_player_reload code %s failed: %s", codeoe, res)
        return client_mgr:callback_errcode(ROLE_RELOAD_REQ, codeoe, session_id)
    end
    for service, server_id in pairs(res) do
        player:update_gateway(service, server_id)
    end
    player:set_lobby_id(lobby)
    session.player_id = player_id
    self.players[player_id] = player
    log_info("[Gateway][on_role_reload_req] user(%s) player(%s) login success!", user_id, player_id)
    client_mgr:callback_errcode(ROLE_RELOAD_REQ, codeoe, session_id)
end

--客户端数据同步
function Gateway:on_session_sync(session)
    local player_id = session.player_id
    local player = self:get_player(player_id)
    if player then
        player:notify_sync()
    end
end

--客户端连接断开
function Gateway:on_session_error(session, token, err)
    local player_id = session.player_id
    local player = self:get_player(player_id)
    if player then
        self.players[player_id] = nil
        player:notify_disconnect()
    end
end

--客户端消息分发
function Gateway:on_session_cmd(session, service_type, cmd_id, body, session_id)
    if service_type == 0 or service_type == service_gate then
        --gateway消息，本地转发
        event_mgr:notify_command(cmd_id, session, body, session_id)
        return
    end
    --转发消息
    local player_id = session.player_id
    local player = self:get_player(player_id)
    if not player then
        log_warn("[Gateway][on_session_cmd] need login, cmd_id=%s, player_id=%s", cmd_id, player_id)
        client_mgr:callback_errcode(session, cmd_id, FRAME_FAILED, session_id)
        return
    end
    player:notify_command(service_type, cmd_id, body, session_id)
end

return Gateway
