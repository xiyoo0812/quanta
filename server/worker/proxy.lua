--proxy.lua
import("feature/worker.lua")

--启动worker
quanta.startup(function()
    import("worker/proxy/proxy_mgr.lua")
    import("worker/proxy/statis_mgr.lua")
end)
