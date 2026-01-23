--lobby_servlet.lua

local log_err           = logger.err
local log_info          = logger.info
local log_warn          = logger.warn
local log_debug         = logger.debug

local event_mgr         = quanta.get("event_mgr")
local player_mgr        = quanta.get("player_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local FRAME_FAILED      = protobuf_mgr:error_code("FRAME_FAILED")
local FRAME_SUCCESS     = protobuf_mgr:error_code("FRAME_SUCCESS")
local ACCOUNT_OFFLINE   = protobuf_mgr:error_code("LOGIN_ACCOUNT_OFFLINE")
local PLAYER_NOT_EXIST  = protobuf_mgr:error_code("LOGIN_PLAYER_NOT_EXIST")

local LobbyServlet = singleton()

function LobbyServlet:__init()
    event_mgr:add_trigger(self, "on_attr_synchronous")
    -- cs协议监听
    protobuf_mgr:register(self, "NID_GATE_LOST_CLIENT_NTF", "on_player_offline_ntf")
    protobuf_mgr:register(self, "NID_LOGIN_PLAYER_LOGIN_REQ", "on_player_login_req")
    protobuf_mgr:register(self, "NID_LOGIN_PLAYER_LOGOUT_REQ", "on_player_logout_req")
    protobuf_mgr:register(self, "NID_LOGIN_PLAYER_RELOAD_REQ", "on_player_reload_req")
end

function LobbyServlet:on_attr_synchronous(entity, entity_id, attrs, battrs)
    if entity:is_player() then
        if next(attrs) then
            entity:send("NID_ENTITY_ATTR_UPDATE_NTF", { id = entity_id, attrs = attrs })
        end
        if next(battrs) then
            player_mgr:broadcast_message("NID_ENTITY_ATTR_UPDATE_NTF", { id = entity_id, attrs = battrs }, entity_id)
        end
    end
end

-- 会话需要关闭
function LobbyServlet:on_player_offline_ntf(session, message, body, response)
    log_warn("[LobbyServlet][on_player_offline_ntf] player({}) offline", body)
    local player_id = body.player_id
    local player = player_mgr:get_entity(player_id)
    if player then
        log_warn("[LobbyServlet][on_player_offline_ntf] player({}) offline", player_id)
        player:offline()
    end
end

function LobbyServlet:on_player_login_req(session, message, body, response)
    log_debug("[LobbyServlet][on_player_login_req] login req body({}) !", body)
    local open_id, player_id = body.open_id, body.player_id
    local player = player_mgr:load_player(open_id, player_id)
    if not player then
        log_err("[LobbyServlet][on_player_login_req] load player failed! player:{}", player_id)
        return message:callback_code(FRAME_FAILED)
    end
    local account = player:get_account()
    if not account then
        log_err("[LobbyServlet][on_player_login_req] local account failed! player:{}", player_id)
        return message:callback_code(ACCOUNT_OFFLINE)
    end
    --玩家上线
    player:online(session)
    account:save_lobby(quanta.id)
    session.player_id = player_id
    --通知登陆成功
    event_mgr:notify_trigger("on_login_success", player_id, player)
    log_info("[LobbyServlet][on_player_login_req] player({}) login success!", player_id)
end

function LobbyServlet:on_player_logout_req(player, message, body, response, player_id)
    log_debug("[LobbyServlet][rpc_player_logout] player({}) logout req!", player_id)
    if not player then
        return message:callback_code(PLAYER_NOT_EXIST)
    end
    player_mgr:remove_entity(player, player_id)
    log_info("[LobbyServlet][rpc_player_logout] player({}) logout success!", player_id)
    return FRAME_SUCCESS
end

function LobbyServlet:on_player_reload_req(player, message, body, response, player_id)
    log_debug("[LobbyServlet][on_player_reload_req] player({}) reload req!", player_id)
    if not player then
        return message:callback_code(PLAYER_NOT_EXIST)
    end
    local account = player:get_account()
    if not account then
        return message:callback_code(ACCOUNT_OFFLINE)
    end
    player:relive()
    event_mgr:notify_trigger("on_reload_success", player_id, player)
    log_debug("[LobbyServlet][rpc_player_reload] player({}) reload success!", player_id)
end

quanta.lobby_servlet = LobbyServlet()

return LobbyServlet
