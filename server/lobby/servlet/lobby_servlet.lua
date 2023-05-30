--lobby_servlet.lua
import("agent/online_agent.lua")

local log_err           = logger.err
local log_info          = logger.info
local log_warn          = logger.warn
local log_debug         = logger.debug
local tunpack           = table.unpack
local mrandom           = qmath.random

local event_mgr         = quanta.get("event_mgr")
local player_mgr        = quanta.get("player_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local FRAME_FAILED      = protobuf_mgr:error_code("FRAME_FAILED")
local FRAME_SUCCESS     = protobuf_mgr:error_code("FRAME_SUCCESS")
local ROLE_NOT_EXIST    = protobuf_mgr:error_code("LOGIN_ROLE_NOT_EXIST")
local ROLE_TOKEN_ERR    = protobuf_mgr:error_code("LOGIN_ROLE_TOKEN_ERR")

local LobbyServlet = singleton()
function LobbyServlet:__init()
    -- 事件监听
    event_mgr:add_listener(self, "rpc_player_sync")
    event_mgr:add_listener(self, "rpc_player_command")
    event_mgr:add_listener(self, "rpc_player_heartbeat")
    event_mgr:add_listener(self, "rpc_player_disconnect")

    event_mgr:add_listener(self, "rpc_player_login")
    event_mgr:add_listener(self, "rpc_player_logout")
    event_mgr:add_listener(self, "rpc_player_reload")
end

-- 会话需要同步
function LobbyServlet:rpc_player_sync(player_id)
    local player = player_mgr:get_entity(player_id)
    if player then
        player:sync_data()
    end
end

-- 会话需要关闭
function LobbyServlet:rpc_player_disconnect(player_id)
    local player = player_mgr:get_entity(player_id)
    if player then
        log_warn("[LobbyServlet][rpc_player_disconnect] player(%s) offline", player_id)
        player:offline()
    end
end

--心跳
function LobbyServlet:rpc_player_heartbeat(player_id)
    local player = player_mgr:get_entity(player_id)
    if player then
        player:heartbeat()
    end
end

-- 会话消息
function LobbyServlet:rpc_player_command(player_id, cmd_id, message)
    local player = player_mgr:get_entity(player_id)
    if not player then
        log_err("[LobbyServlet][rpc_player_command] need login cmd_id=%s, player_id=%s", cmd_id, player_id)
        return ROLE_NOT_EXIST
    end
    local result = event_mgr:notify_command(cmd_id, player, player_id, message)
    if not result[1] then
        return FRAME_FAILED, result[2]
    end
    return tunpack(result, 2)
end

function LobbyServlet:rpc_player_login(open_id, player_id, lobby, token, gateway)
    log_debug("[LobbyServlet][rpc_player_login] user(%s) player(%s) token(%s) gateway(%s) login req!", open_id, player_id, token, gateway)
    local account, login_token = player_mgr:load_account(open_id, player_id)
    if not account or not login_token then
        return ROLE_TOKEN_ERR
    end
    --验证token
    if tostring(token) ~= login_token or lobby ~= quanta.id then
        log_err("[LobbyServlet][rpc_player_login] token verify failed! player:%s, lobby: %s-%s", player_id, lobby, quanta.id)
        log_err("[LobbyServlet][rpc_player_login] token verify failed! player:%s, token: %s-%s", player_id, token, login_token)
        return ROLE_TOKEN_ERR
    end
    local player = player_mgr:load_player(account, player_id, gateway)
    if not player then
        return FRAME_FAILED
    end
    --通知登陆成功
    local new_token = mrandom()
    account:set_reload_token(new_token)
    local passkey = player:get_passkey()
    event_mgr:fire_next_frame(function()
        --玩家上线
        player:online(gateway)
        --通知登陆成功
        event_mgr:notify_trigger("on_login_success", player_id, player)
    end)
    log_info("[LobbyServlet][rpc_player_login] player(%s) login success!", player_id)
    return FRAME_SUCCESS, passkey, new_token
end

function LobbyServlet:rpc_player_logout(player_id)
    log_debug("[LobbyServlet][rpc_player_logout] player(%s) logout req!", player_id)
    local player = player_mgr:get_entity(player_id)
    if not player then
        return ROLE_NOT_EXIST
    end
    player_mgr:remove_entity(player, player_id)
    log_info("[LobbyServlet][rpc_player_logout] player(%s) logout success!", player_id)
    return FRAME_SUCCESS
end

function LobbyServlet:rpc_player_reload(open_id, player_id, lobby, token, gateway)
    log_debug("[LobbyServlet][rpc_player_reload] player(%s) reload req!", player_id)
    local player = player_mgr:get_entity(player_id)
    if not player then
        return FRAME_SUCCESS, 0
    end
    local account = player:get_account()
    if not account then
        return ROLE_TOKEN_ERR
    end
    --验证token
    local old_token = account:get_reload_token()
    if token ~= old_token or lobby ~= quanta.id then
        log_err("[LobbyServlet][rpc_player_login] token verify failed! player:%s, lobby: %s-%s", player_id, lobby, quanta.id)
        log_err("[LobbyServlet][rpc_player_login] token verify failed! player:%s, token: %s-%s", player_id, token, old_token)
        return ROLE_TOKEN_ERR
    end
    player:relive(gateway)
    local new_token = mrandom()
    account:set_reload_token(new_token)
    event_mgr:notify_trigger("on_reload_success", player_id, player)
    log_debug("[LobbyServlet][rpc_player_reload] player(%s) reload success!", player_id)
    return FRAME_SUCCESS, new_token, player:get_passkey()
end

quanta.lobby_servlet = LobbyServlet()

return LobbyServlet
