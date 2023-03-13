--login_servlet.lua
import("agent/online_agent.lua")

local log_err           = logger.err
local log_info          = logger.info
local log_warn          = logger.warn
local log_debug         = logger.debug
local tunpack           = table.unpack
local mrandom           = qmath.random
local qfailed           = quanta.failed

local online            = quanta.get("online")
local game_dao          = quanta.get("game_dao")
local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local player_mgr        = quanta.get("player_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local FRAME_FAILED      = protobuf_mgr:error_code("FRAME_FAILED")
local FRAME_SUCCESS     = protobuf_mgr:error_code("FRAME_SUCCESS")
local ROLE_NOT_EXIST    = protobuf_mgr:error_code("LOGIN_ROLE_NOT_EXIST")
local ROLE_TOKEN_ERR    = protobuf_mgr:error_code("LOGIN_ROLE_TOKEN_ERR")

local LoginServlet = singleton()
function LoginServlet:__init()
    -- 事件监听
    event_mgr:add_listener(self, "rpc_player_sync")
    event_mgr:add_listener(self, "rpc_player_command")
    event_mgr:add_listener(self, "rpc_player_heartbeat")
    event_mgr:add_listener(self, "rpc_player_disconnect")

    event_mgr:add_listener(self, "rpc_player_login")
    event_mgr:add_listener(self, "rpc_player_logout")
    event_mgr:add_listener(self, "rpc_player_reload")

    -- 注册存储结构
    game_dao:add_sheet(nil, "account", "open_id", { account = 1 })
    game_dao:add_sheet("player", "player", "player_id", { player = 1 })
    game_dao:add_sheet("player", "player_attr", "player_id", { player_attr = 1 })
end

-- 会话需要同步
function LoginServlet:rpc_player_sync(player_id)
    local player = player_mgr:get_entity(player_id)
    if player then
        player:sync_data()
    end
end

-- 会话需要关闭
function LoginServlet:rpc_player_disconnect(player_id)
    local player = player_mgr:get_entity(player_id)
    if player then
        log_warn("[LoginServlet][rpc_player_disconnect] player(%s) offline", player_id)
        player:offline()
    end
end

--心跳
function LoginServlet:rpc_player_heartbeat(player_id)
    local player = player_mgr:get_entity(player_id)
    if player then
        player:heartbeat()
    end
end

-- 会话消息
function LoginServlet:rpc_player_command(player_id, cmd_id, message)
    local player = player_mgr:get_entity(player_id)
    if not player then
        log_err("[LoginServlet][rpc_player_command] need login cmd_id=%s, player_id=%s", cmd_id, player_id)
        return ROLE_NOT_EXIST
    end
    local result = event_mgr:notify_command(cmd_id, player, player_id, message)
    if not result[1] then
        return FRAME_FAILED, result[2]
    end
    return tunpack(result, 2)
end

function LoginServlet:rpc_player_login(open_id, player_id, lobby, token, gateway)
    log_debug("[LoginServlet][rpc_player_login] user(%s) player(%s) token(%s) gateway(%s) login req!", open_id, player_id, token, gateway)
    local account = player_mgr:load_account(open_id)
    if not account then
        return FRAME_FAILED
    end
    --验证token
    if token ~= account:get_login_token() or lobby ~= account:get_lobby() or quanta.now > account:get_login_time() then
        log_err("[LoginServlet][rpc_player_login] token verify failed! player:%s, lobby: %s-%s", player_id, lobby, account:get_lobby())
        log_err("[LoginServlet][rpc_player_login] token verify failed! player:%s, token: %s-%s", player_id, token, account:get_login_token())
        log_err("[LoginServlet][rpc_player_login] token verify failed! player:%s, time: %s-%s", player_id, quanta.now, account:get_login_time())
        return ROLE_TOKEN_ERR
    end
    local player = player_mgr:load_player(player_id)
    if not player then
        return FRAME_FAILED
    end
    --online
    player:set_gateway(gateway)
    if not player:online() then
        return FRAME_FAILED
    end
    --通知online
    local passkey = player:get_passkey()
    local lok, code = online:login_player(player, passkey)
    if qfailed(code, lok) then
        return FRAME_FAILED
    end
    --通知登陆成功
    local new_token = mrandom()
    player:set_account(account)
    account:set_login_token(new_token)
    update_mgr:attach_event(player_id, "on_login_success", player_id, player)
    log_info("[LoginServlet][rpc_player_login] player(%s) login success!", player_id)
    return FRAME_SUCCESS, passkey, new_token
end

function LoginServlet:rpc_player_logout(player_id)
    log_debug("[LoginServlet][rpc_player_logout] player(%s) logout req!", player_id)
    local player = player_mgr:get_entity(player_id)
    if not player then
        return ROLE_NOT_EXIST
    end
    player_mgr:remove_entity(player, player_id)
    log_info("[LoginServlet][rpc_player_logout] player(%s) logout success!", player_id)
    return FRAME_SUCCESS
end

function LoginServlet:rpc_player_reload(open_id, player_id, lobby, token, gateway)
    log_debug("[LoginServlet][rpc_player_reload] player(%s) reload req!", player_id)
    local player = player_mgr:get_entity(player_id)
    if not player then
        return ROLE_NOT_EXIST
    end
    local account = player_mgr:load_account(open_id)
    if not account then
        return FRAME_FAILED
    end
    --验证token
    local old_token = account:get_login_token()
    if token ~= old_token or lobby ~= account:get_lobby() then
        log_err("[LoginServlet][rpc_player_reload] token verify failed! player:%s, token: %s, old_token=%s", player_id, token, old_token)
        return ROLE_TOKEN_ERR
    end
    local new_token = mrandom()
    player:relive(gateway)
    player:set_account(account)
    account:set_login_token(new_token)
    log_debug("[LoginServlet][rpc_player_reload] player(%s) reload success!", player_id)
    update_mgr:attach_event(player_id, "on_reload_success", player_id, player)
    return FRAME_SUCCESS, player:get_passkey(), new_token
end

quanta.login_servlet = LoginServlet()

return LoginServlet
