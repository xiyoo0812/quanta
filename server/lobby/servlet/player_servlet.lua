--player_servlet.lua

local log_info          = logger.info

local event_mgr         = quanta.get("event_mgr")
local player_mgr        = quanta.get("player_mgr")

local PlayerServlet = singleton()
function PlayerServlet:__init()
    --注册消息
    event_mgr:add_trigger(self, "on_login_success")
    event_mgr:add_trigger(self, "on_logout_success")
    event_mgr:add_trigger(self, "on_reload_success")
    event_mgr:add_trigger(self, "on_kickout_success")
    -- rpc监听
    event_mgr:add_listener(self, "rpc_reliable_event")
end

--rpc
------------------------------------------------
--可靠事件分发
function PlayerServlet:rpc_reliable_event(player_id)
    local player = player_mgr:get_entity(player_id)
    if player then
        event_mgr:publish_frame(player, "load_reliable_events")
    end
end

--内部事件
------------------------------------------------
--登陆成功
function PlayerServlet:on_login_success(player_id, player)
    log_info("[PlayerServlet][on_login_success] player({}) login success!", player_id)
    --开启属性同步
    local pb_attrs = { id = player_id, attrs = player:package_attrs(1) }
    player:send("NID_ENTITY_ATTR_UPDATE_NTF", pb_attrs)
    --加载可靠消息
    --event_mgr:publish_frame(player, "load_reliable_events")
end

--登出成功
function PlayerServlet:on_logout_success(player_id, player)
    log_info("[PlayerServlet][on_logout_success] player({}) logout success!", player_id)
end

--踢人成功
function PlayerServlet:on_kickout_success(player_id, player)
    log_info("[PlayerServlet][on_kickout_success] player({}) kickout success!", player_id)
    player_mgr:remove_entity(player, player_id)
end

--重连成功
function PlayerServlet:on_reload_success(player_id, player)
    log_info("[PlayerServlet][on_reload_success] player({}) reload success!", player_id)
end

quanta.player_servlet = PlayerServlet()

return PlayerServlet
