--router.lua
import("kernel.lua")

quanta.startup(function()
    --初始化router
    import("router/router_server.lua")
    --初始化transfer
    import("router/transfer_mgr.lua")
end)
