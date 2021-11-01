--router.lua
import("kernel.lua")

quanta.startup(function()
    --初始化router
    import("router/router_server.lua")
end)
