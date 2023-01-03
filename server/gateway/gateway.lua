--gateway.lua
local log_err           = logger.err
local log_info          = logger.info
local log_warn          = logger.warn
local log_debug         = logger.debug
local qfailed           = quanta.failed
local name2sid          =  service.name2sid

local event_mgr         = quanta.get("event_mgr")
local client_mgr        = quanta.get("client_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local GatePlayer     	= import("gateway/player.lua")

local FRAME_FAILED      = protobuf_mgr:error_code("FRAME_FAILED")
local DEVICE_REPLACE    = protobuf_mgr:error_code("KICK_DEVICE_REPLACE")
local ROLE_IS_INLINE    = protobuf_mgr:error_code("LOGIN_ROLE_IS_INLINE")

local SERVICE_GATE      = name2sid("gateway")

local Gateway = singleton()
local prop = property(Gateway)
prop:reader("players", {})          --会话列表

function Gateway:__init()
    -- 网络事件监听
    event_mgr:add_listener(self, "on_session_cmd")
    event_mgr:add_listener(self, "on_session_sync")
    event_mgr:add_listener(self, "on_session_error")
    event_mgr:add_listener(self, "on_socket_accept")
    -- rpc消息监听
    event_mgr:add_listener(self, "rpc_update_gateway")
    event_mgr:add_listener(self, "rpc_kickout_client")
    event_mgr:add_listener(self, "rpc_forward_client")
    event_mgr:add_listener(self, "rpc_groupcast_client")
    event_mgr:add_listener(self, "rpc_broadcast_client")
    -- cs协议监听
    protobuf_mgr:register(self, "NID_HEARTBEAT_REQ", "on_heartbeat_req")
    protobuf_mgr:register(self, "NID_LOGIN_ROLE_LOGIN_REQ", "on_role_login_req")
    protobuf_mgr:register(self, "NID_LOGIN_ROLE_LOGOUT_REQ", "on_role_logout_req")
    protobuf_mgr:register(self, "NID_LOGIN_ROLE_RELOAD_REQ", "on_role_reload_req")
    -- 重新设置
    local nport = client_mgr:get_port()
    local domain = environ.get("QUANTA_DOMAIN_ADDR")
    service.make_node(nport, domain)
end

--查找玩家
function Gateway:get_player(player_id)
    if player_id then
        return self.players[player_id]
    end
end

--更新网关信息
function Gateway:rpc_update_gateway(player_id, service_name, server_id)
    local player = self:get_player(player_id)
    if player then
        local service_type = name2sid(service_name)
        player:update_gateway(service_type, server_id)
    end
end

function Gateway:close_session(session, player_id)
    client_mgr:close_session(session)
    self.players[player_id] = nil
end

--踢掉客户端
function Gateway:kickout_client(player, player_id, reason)
    player:send_message("NID_LOGIN_ROLE_KICKOUT_NTF", { reason = reason })
    self:close_session(player:get_session(), player_id)
end

--踢掉客户端
function Gateway:rpc_kickout_client(player_id, reason)
    local player = self:get_player(player_id)
    if player then
        self:kickout_client(player, player_id, reason)
    end
end

--转发给客户端
function Gateway:rpc_forward_client(player_id, cmd_id, data)
    local player = self:get_player(player_id)
    if not player then
        log_warn("[Gateway][rpc_forward_client] cmd_id(%s) player(%s) not exist!", cmd_id, player_id)
        return
    end
    player:send_message(cmd_id, data)
end

--组发消息
function Gateway:rpc_groupcast_client(player_ids, cmd_id, data)
    for _, player_id in pairs(player_ids) do
        self:rpc_forward_client(player_id, cmd_id, data)
    end
end

--广播给客户端
function Gateway:rpc_broadcast_client(cmd_id, data)
    client_mgr:broadcast(cmd_id, data)
end

--心跳协议
function Gateway:on_heartbeat_req(session, cmd_id, body, session_id)
    local player = self:get_player(session.player_id)
    if player then
        player:notify_heartbeat(session, cmd_id, body, session_id)
    end
end

--玩家登陆
function Gateway:on_role_login_req(session, cmd_id, body, session_id)
    local user_id, player_id, lobby, token = body.user_id, body.role_id, body.lobby, body.token
    log_debug("[Gateway][on_role_login_req] user(%s) player(%s) login start!", user_id, player_id)
    local player = self:get_player(player_id)
    if player then
        local osession = player:get_session()
        if osession == session then
            --重复发送
            log_err("[Gateway][on_role_login_req] player (%s) call repeated login req",  player_id)
            return client_mgr:callback_errcode(session, cmd_id, ROLE_IS_INLINE, session_id)
        end
        --踢掉老连接，设置新连接
        self:kickout_client(player, player_id, DEVICE_REPLACE)
        player:set_session(session)
    else
        player = GatePlayer(session, user_id, player_id)
    end
    local codeoe, res = player:trans_message(lobby, "rpc_player_login", user_id, player_id, token, quanta.id)
    if qfailed(codeoe) then
        log_err("[Gateway][on_role_login_req] player (%s) call rpc_player_login code %s failed: %s", player_id, codeoe, res)
        return client_mgr:callback_errcode(session, cmd_id, codeoe, session_id)
    end
    for service_name, server_id in pairs(res) do
        local service_type = name2sid(service_name)
        player:update_gateway(service_type, server_id)
    end
    player:set_lobby_id(lobby)
    session.player_id = player_id
    self.players[player_id] = player
    log_info("[Gateway][on_role_login_req] user(%s) player(%s) login success!", user_id, player_id)
    client_mgr:callback_errcode(session, cmd_id, codeoe, session_id)
end

--玩家登出
function Gateway:on_role_logout_req(session, cmd_id, body, session_id)
    local player_id = body.role_id
    log_debug("[Gateway][on_role_logout_req] player(%s) logout start!", player_id)
    local player = self:get_player(player_id)
    if player then
        local codeoe, token = player:trans_message(player:get_lobby_id(), "rpc_player_logout", player_id)
        if qfailed(codeoe) then
            log_err("[Gateway][on_role_logout_req] call rpc_player_logout code %s failed: %s", codeoe, token)
            return client_mgr:callback_errcode(session, cmd_id, codeoe, session_id)
        end
        log_info("[Gateway][on_role_logout_req] player(%s) logout success!", player_id)
        local callback_data = { error_code = codeoe, account_token = token}
        client_mgr:callback_by_id(session, cmd_id, callback_data, session_id)
        self:close_session(session, player_id)
    end
end

--玩家重登
function Gateway:on_role_reload_req(session, cmd_id, body, session_id)
    local user_id, player_id, lobby, token = body.user_id, body.role_id, body.lobby, body.token
    log_debug("[Gateway][on_role_reload_req] user(%s) player(%s) reload start!", user_id, player_id)
    local player = self:get_player(player_id)
    if player then
        local osession = player:get_session()
        if osession == session then
            --重复发送
            log_err("[Gateway][on_role_reload_req] player (%s) call repeated reload req",  player_id)
            return client_mgr:callback_errcode(session, cmd_id, ROLE_IS_INLINE, session_id)
        end
        --关闭老连接，设置新连接
        self:close_session(osession, player_id)
        player:set_session(session)
    else
        player = GatePlayer(session, user_id, player_id)
    end
    if session.player_id then
        return client_mgr:callback_errcode(session, cmd_id, ROLE_IS_INLINE, session_id)
    end
    local codeoe, res = player:trans_message(lobby, "rpc_player_reload", user_id, player_id, lobby, token, quanta.id)
    if qfailed(codeoe) then
        log_err("[Gateway][on_role_reload_req] call rpc_player_reload code %s failed: %s", codeoe, res)
        return client_mgr:callback_errcode(session, cmd_id, codeoe, session_id)
    end
    for service_name, server_id in pairs(res) do
        local service_type = name2sid(service_name)
        player:update_gateway(service_type, server_id)
    end
    player:set_lobby_id(lobby)
    session.player_id = player_id
    self.players[player_id] = player
    log_info("[Gateway][on_role_reload_req] user(%s) player(%s) login success!", user_id, player_id)
    client_mgr:callback_errcode(session, cmd_id, codeoe, session_id)
end

--连接信息
----------------------------------------------------------------------
--客户端连上
function Gateway:on_socket_accept(session)
    log_debug("[Gateway][on_socket_accept] %s connected!", session.token)
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
        log_warn("[Gateway][on_session_error] session(%s-%s) lost, because: %s!", token, player_id, err)
        self.players[player_id] = nil
        player:notify_disconnect()
    end
end

--客户端消息分发
function Gateway:on_session_cmd(session, service_type, cmd_id, body, session_id)
    if service_type == 0 or service_type == SERVICE_GATE then
        --gateway消息，本地转发
        event_mgr:notify_command(cmd_id, session, cmd_id, body, session_id, cmd_id)
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

quanta.gateway = Gateway()

return Gateway
