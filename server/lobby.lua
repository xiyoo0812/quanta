#!./quanta
import("kernel.lua")

quanta.startup(function()
    --初始化lobby
    import("lobby/player/lobby_dao.lua")
    import("lobby/player/player_mgr.lua")
    import("lobby/servlet/login_servlet.lua")
    import("business/attr/attribute_relay.lua")
end)
