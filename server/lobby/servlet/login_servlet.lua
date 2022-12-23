--login_servlet.lua
import("agent/online_agent.lua")

local log_err           = logger.err
local log_info          = logger.info
local log_warn          = logger.warn
local log_debug         = logger.debug
local tunpack           = table.unpack
local qfailed           = quanta.failed

local online            = quanta.get("online")
local login_dao         = quanta.get("login_dao")
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
    event_mgr:add_listener(self, "rpc_player_heatbeat")
    event_mgr:add_listener(self, "rpc_player_disconnect")

    event_mgr:add_listener(self, "rpc_player_login")
    event_mgr:add_listener(self, "rpc_player_logout")
    event_mgr:add_listener(self, "rpc_player_reload")
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
function LoginServlet:rpc_player_heatbeat(player_id)
    local player = player_mgr:get_entity(player_id)
    if player then
        return player:get_token()
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

function LoginServlet:rpc_player_login(user_id, player_id, token, gateway)
    log_debug("[LoginServlet][rpc_player_login] user(%s) player(%s) token(%s) gateway(%s) login req!", user_id, player_id, token, gateway)
    local ok, adata = login_dao:load_account_status(user_id)
    if not ok then
        return FRAME_FAILED
    end
    --验证token
    if not adata or token ~= adata.login_token or quanta.now > adata.login_time then
        log_err("[LoginServlet][rpc_player_login] token verify failed! player:%s, time: %s, adata=%s", player_id, quanta.now, adata)
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
    update_mgr:attach_event(player_id, "on_login_success", player_id, player)
    log_info("[LoginServlet][rpc_player_login] player(%s) login success!", player_id)
    return FRAME_SUCCESS, passkey
end

function LoginServlet:rpc_player_logout(player_id)
    log_debug("[LoginServlet][rpc_player_logout] player(%s) logout req!", player_id)
    local player = player_mgr:get_entity(player_id)
    if not player then
        return ROLE_NOT_EXIST
    end
    local token = player:update_token()
    player_mgr:remove_entity(player, player_id)
    log_info("[LoginServlet][rpc_player_logout] player(%s) logout success!", player_id)
    return FRAME_SUCCESS, token
end

function LoginServlet:rpc_player_reload(user_id, player_id, lobby, token, gateway)
    log_debug("[LoginServlet][rpc_player_reload] player(%s) reload req!", player_id)
    local player = player_mgr:get_entity(player_id)
    if not player then
        return ROLE_NOT_EXIST
    end
    if player:get_token() ~= token then
        log_err("[LoginServlet][rpc_player_reload] player(%s) token(%s, %s) not match!", player_id, token, player:get_token())
        return ROLE_TOKEN_ERR
    end
    player:relive()
    player:set_gateway(gateway)
    log_debug("[LoginServlet][rpc_player_reload] player(%s) reload success!", player_id)
    update_mgr:attach_event(player_id, "on_reload_success", player_id, player)
    return FRAME_SUCCESS, player:get_passkey()
end

quanta.login_servlet = LoginServlet()

return LoginServlet
