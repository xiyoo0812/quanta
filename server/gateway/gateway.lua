--gateway.lua
local log_err           = logger.err
local log_info          = logger.info
local log_warn          = logger.warn
local log_debug         = logger.debug
local qfailed           = quanta.failed
local qdefer            = quanta.defer
local sformat           = string.format
local name2sid          = service.name2sid

local discover          = quanta.get("discover")
local event_mgr         = quanta.get("event_mgr")
local group_mgr         = quanta.get("group_mgr")
local config_mgr        = quanta.get("config_mgr")
local router_mgr        = quanta.get("router_mgr")
local client_mgr        = quanta.get("client_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local GatePlayer     	= import("gateway/player.lua")

local filter            = config_mgr:init_table("filter", "name")

local FRAME_FAILED      = protobuf_mgr:error_code("FRAME_FAILED")
local FRAME_UPHOLD      = protobuf_mgr:error_code("FRAME_UPHOLD")
local FRAME_TOOFAST     = protobuf_mgr:error_code("FRAME_TOOFAST")
local SERVER_UPHOLD     = protobuf_mgr:error_code("KICK_SERVER_UPHOLD")
local DEVICE_REPLACE    = protobuf_mgr:error_code("KICK_DEVICE_REPLACE")
local ROLE_IS_INLINE    = protobuf_mgr:error_code("LOGIN_ROLE_IS_INLINE")

local SERVICE_GATE      = name2sid("gateway")

local Gateway = singleton()
local prop = property(Gateway)
prop:reader("players", {})          --会话列表
prop:reader("counter", nil)         --计数器
prop:reader("req_counter", nil)     --计数器
prop:reader("ntf_counter", nil)     --计数器
prop:reader("ignore_cmds", {})      --日志过滤
prop:reader("reenter_cmds", {})     --重入过滤

function Gateway:__init()
    -- 网络事件监听
    event_mgr:add_listener(self, "on_socket_cmd")
    event_mgr:add_listener(self, "on_socket_error")
    event_mgr:add_listener(self, "on_socket_accept")
    -- rpc消息监听
    event_mgr:add_listener(self, "rpc_update_group")
    event_mgr:add_listener(self, "rpc_kickout_client")
    event_mgr:add_listener(self, "rpc_forward_client")
    event_mgr:add_listener(self, "rpc_groupcast_client")
    event_mgr:add_listener(self, "rpc_broadcast_client")
    event_mgr:add_listener(self, "rpc_broadcast_group")
    event_mgr:add_listener(self, "rpc_broadcast_groupname")
    event_mgr:add_listener(self, "rpc_service_svr_changed")
    -- cs协议监听
    protobuf_mgr:register(self, "NID_HEARTBEAT_REQ", "on_heartbeat_req")
    protobuf_mgr:register(self, "NID_LOGIN_ROLE_LOGIN_REQ", "on_role_login_req")
    protobuf_mgr:register(self, "NID_LOGIN_ROLE_LOGOUT_REQ", "on_role_logout_req")
    protobuf_mgr:register(self, "NID_LOGIN_ROLE_RELOAD_REQ", "on_role_reload_req")
    -- 重新设置
    local nport = client_mgr:get_port()
    local domain = environ.get("QUANTA_DOMAIN_ADDR", luabus.host())
    service.modify_host(nport, domain)
    --日志过滤
    self:init_filter()
    --计数器
    self.counter = quanta.make_counter(sformat("gateway %s player", quanta.index))
    self.req_counter = quanta.make_sampling(sformat("gateway %s req", quanta.index))
    self.ntf_counter = quanta.make_sampling(sformat("gateway %s ntf", quanta.index))
    --关注lobby
    discover:watch_service(self, "lobby")
end

--lobby关闭
----------------------------------------------------------------
function Gateway:on_service_close(id, name, info)
    log_debug("[Gateway][on_service_close] node: {}-{}", name, id)
    for player_id, player in pairs(self.players) do
        if player:get_lobby_id() == id then
            self:kickout_client(player, player_id, SERVER_UPHOLD)
        end
    end
end

---是否输出CMD消息的内容
function Gateway:init_filter()
    self:on_cfg_filter_changed()
    event_mgr:add_trigger(self, "on_cfg_filter_changed")
end

---日志忽略网络消息通知名
function Gateway:on_cfg_filter_changed()
    self.ignore_cmds = {}
    for cmd_name, conf in filter:iterator() do
        local cmd_id = protobuf_mgr:msg_id(cmd_name)
        if conf.log then
            self.ignore_cmds[cmd_id] = true
            self.ignore_cmds[cmd_name] = true
        end
        if conf.proto then
            self.reenter_cmds[cmd_id] = true
        end
    end
end

---是否输出CMD消息的内容
function Gateway:is_print_cmd(cmd_id)
    if self.ignore_cmds[cmd_id] then
        return false
    end
    return true
end

--查找玩家
function Gateway:get_player(player_id)
    if player_id then
        return self.players[player_id]
    end
end

--更新分组信息
function Gateway:rpc_update_group(player_id, group_name, group_id)
    log_debug("[Gateway][rpc_update_group] player({}) group_name({}) group_id({})", player_id, group_name, group_id)
    local player = self:get_player(player_id)
    if player then
        player:update_group(group_name, group_id)
    else
        log_warn("[Gateway][rpc_update_group] not player player({}) group_name({}) group_id({})", player_id, group_name, group_id)
    end
end

--玩家关闭
function Gateway:remove_player(player, player_id)
    self.counter:count_reduce()
    self.players[player_id] = nil
    local groups = player:get_groups()
    for _, group_id in pairs(groups or {}) do
        group_mgr:remove_member(group_id, player_id)
    end
end

--玩家关闭
function Gateway:close_client(player, player_id)
    self:remove_player(player, player_id)
    client_mgr:close_session(player:get_session())
end

--添加玩家
function Gateway:add_player(player, player_id, lobby, token)
    player:set_token(token)
    player:set_lobby_id(lobby)
    self.players[player_id] = player
    self.counter:count_increase()
end

--踢掉客户端
function Gateway:kickout_client(player, player_id, reason)
    player:send_message("NID_LOGIN_ROLE_KICKOUT_NTF", { reason = reason })
    self:close_client(player, player_id)
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
    self.ntf_counter:count_increase()
    local player = self:get_player(player_id)
    if not player then
        log_warn("[Gateway][rpc_forward_client] cmd_id({}) player({}) not exist!", cmd_id, player_id)
        return
    end
    player:send_message(cmd_id, data, self:is_print_cmd(cmd_id))
end

--群发消息
function Gateway:rpc_groupcast_client(player_ids, cmd_id, data)
    local tokens = {}
    for _, player_id in pairs(player_ids) do
        local player = self:get_player(player_id)
        if player then
            tokens[#tokens + 1] = player:get_session_token()
        end
    end
    if next(tokens) then
        client_mgr:broadcast_groups(tokens, cmd_id, data)
    end
end

--组发消息
function Gateway:rpc_broadcast_group(group_id, cmd_id, data)
    group_mgr:broadcast(group_id, cmd_id, data)
end

--组发消息
function Gateway:rpc_broadcast_groupname(player_id, group_name, cmd_id, data)
    local player = self:get_player(player_id)
    if player then
        local group_id = player:get_group_id(group_name)
        router_mgr:call_gateway_all("rpc_broadcast_group", group_id, cmd_id, data)
        group_mgr:broadcast(group_id, cmd_id, data)
    end
end

--服务svr发生改变
function Gateway:rpc_service_svr_changed(player_id)
    local player = self:get_player(player_id)
    if player then
        log_debug("[Gateway][rpc_service_svr_changed] player({}) switch gateway, will kickout!", player_id)
        self:kickout_client(player, player_id, DEVICE_REPLACE)
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

function Gateway:call_lobby(lobby, rpc, player_id, ...)
    local ok, codeore, res = router_mgr:call_target_hash(lobby, player_id, rpc, player_id, ...)
    if not ok then
        return FRAME_FAILED, codeore
    end
    return codeore, res
end

--玩家登陆
function Gateway:on_role_login_req(session, cmd_id, body, session_id)
    local open_id, player_id, lobby, token = body.open_id, body.role_id, body.lobby, body.token
    log_debug("[Gateway][on_role_login_req] user({}) player({}) login start!", open_id, player_id)
    local player = self:get_player(player_id)
    if player then
        local osession = player:get_session()
        if osession == session then
            --重复发送
            log_err("[Gateway][on_role_login_req] player ({}) call repeated login req",  player_id)
            return client_mgr:callback_errcode(session, cmd_id, ROLE_IS_INLINE, session_id)
        end
        --踢掉老连接，设置新连接
        self:kickout_client(player, player_id, DEVICE_REPLACE)
        player:set_session(session)
    else
        player = GatePlayer(session, open_id, player_id)
    end
    router_mgr:login_service(player_id, "gateway", quanta.id)
    local code, new_token = self:call_lobby(lobby, "rpc_player_login", player_id, open_id, token)
    if qfailed(code) then
        log_err("[Gateway][on_role_login_req] player ({}) call rpc_player_login code {} failed: {}", player_id, code, new_token)
        return client_mgr:callback_errcode(session, cmd_id, code, session_id)
    end
    session.player_id = player_id
    self:add_player(player, player_id, lobby, new_token)
    log_info("[Gateway][on_role_login_req] user:{} player:{}, new_token:{} login success!", open_id, player_id, new_token)
    local callback_data = { error_code = code, token = new_token}
    client_mgr:callback_by_id(session, cmd_id, callback_data, session_id)
end

--玩家登出
function Gateway:on_role_logout_req(session, cmd_id, body, session_id)
    local player_id = body.role_id
    log_debug("[Gateway][on_role_logout_req] player({}) logout start!", player_id)
    local player = self:get_player(player_id)
    if player then
        local code, err = self:call_lobby(player:get_lobby_id(), "rpc_player_logout", player_id)
        if qfailed(code) then
            log_err("[Gateway][on_role_logout_req] call rpc_player_logout code {} failed: {}", code, err)
            return client_mgr:callback_errcode(session, cmd_id, code, session_id)
        end
        router_mgr:login_service(player_id, "gateway", 0)
        log_info("[Gateway][on_role_logout_req] player({}) logout success!", player_id)
        client_mgr:callback_errcode(session, cmd_id, code, session_id)
        self:close_client(player, player_id)
    end
end

--玩家重登
function Gateway:on_role_reload_req(session, cmd_id, body, session_id)
    local open_id, player_id, lobby, token = body.open_id, body.role_id, body.lobby, body.token
    log_debug("[Gateway][on_role_reload_req] user:{} player:{} token:{} reload start!", open_id, player_id, token)
    local player = self:get_player(player_id)
    if player then
        local osession = player:get_session()
        if osession == session then
            --重复发送
            log_err("[Gateway][on_role_reload_req] player ({}) call repeated reload req",  player_id)
            return client_mgr:callback_errcode(session, cmd_id, ROLE_IS_INLINE, session_id)
        end
        --踢掉老连接，设置新连接
        self:kickout_client(player, player_id, DEVICE_REPLACE)
        player:set_session(session)
    else
        player = GatePlayer(session, open_id, player_id)
    end
    if session.player_id then
        return client_mgr:callback_errcode(session, cmd_id, ROLE_IS_INLINE, session_id)
    end
    router_mgr:login_service(player_id, "gateway", quanta.id)
    local code, new_token = self:call_lobby(lobby, "rpc_player_reload", player_id, token)
    if qfailed(code) then
        log_err("[Gateway][on_role_reload_req] call rpc_player_reload code {} failed: {}", code, new_token)
        return client_mgr:callback_by_id(session, cmd_id, { error_code = 0, token = 0 }, session_id)
    end
    if new_token > 0 then
        session.player_id = player_id
        self:add_player(player, player_id, lobby, new_token)
    end
    log_info("[Gateway][on_role_reload_req] user:{} player:{} new_token:{} reload success!", open_id, player_id, new_token)
    local callback_data = { error_code = code, token = new_token}
    client_mgr:callback_by_id(session, cmd_id, callback_data, session_id)
end

--连接信息
----------------------------------------------------------------------
--客户端连上
function Gateway:on_socket_accept(session)
    --log_debug("[Gateway][on_socket_accept] {} connected!", session.token)
end

--客户端连接断开
function Gateway:on_socket_error(session, token, err)
    local player_id = session.player_id
    local player = self:get_player(player_id)
    if player then
        log_warn("[Gateway][on_socket_error] session({}-{}) lost, because: {}!", token, player_id, err)
        self:remove_player(player, player_id)
        router_mgr:login_service(player_id, "gateway", 0)
        player:notify_disconnect()
    end
end

--客户端消息分发
function Gateway:on_socket_cmd(session, service_type, cmd_id, body, session_id)
    -- 协议过滤
    self.req_counter:count_increase()
    local result = event_mgr:notify_listener("on_proto_filter", cmd_id, service_type)
    if result[1] and result[2] then
        log_warn("[Gateway][on_socket_cmd] on_proto_filter false, cmd_id={}", cmd_id)
        client_mgr:callback_errcode(session, cmd_id, FRAME_UPHOLD, session_id)
        return
    end
    -- 协议锁
    local hook<close> = qdefer()
    if self.reenter_cmds[cmd_id] then
        local lock_key = sformat("%s_%s", session.token, cmd_id)
        hook:register(function()
            thread_mgr:unlock(lock_key)
        end)
        if not thread_mgr:lock(lock_key, false) then
            log_warn("[Gateway][on_socket_cmd] check lock failed, cmd_id={}, {}", cmd_id, lock_key)
            client_mgr:callback_errcode(session, cmd_id, FRAME_TOOFAST, session_id)
            return
        end
    end
    if service_type == 0 or service_type == SERVICE_GATE then
        --gateway消息，本地转发
        event_mgr:notify_command(cmd_id, session, cmd_id, body, session_id, cmd_id)
        return
    end
    --转发消息
    local player_id = session.player_id
    local player = self:get_player(player_id)
    if not player then
        log_warn("[Gateway][on_socket_cmd] need login, cmd_id={}, player_id={}", cmd_id, player_id)
        client_mgr:callback_errcode(session, cmd_id, FRAME_FAILED, session_id)
        return
    end
    player:notify_command(service_type, cmd_id, body, session_id, self:is_print_cmd(cmd_id))
end

quanta.gateway = Gateway()

return Gateway
