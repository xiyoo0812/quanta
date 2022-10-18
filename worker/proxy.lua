--proxy_mgr.lua
import("driver/worker.lua")

--启动worker
quanta.startup(function()
    import("proxy/proxy_mgr.lua")
end)
