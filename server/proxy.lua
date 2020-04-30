--proxy.lua
import("kernel.lua")
local log_info      = logger.info
local qxpcall       = quanta.xpcall
local quanta_update = quanta.update

if not quanta.init_flag then
    --初始化quanta
    qxpcall(quanta.init, "quanta.init error: %s")

    import("proxy/proxy_mgr.lua")

    log_info("proxy %d now startup!", quanta.id)
    quanta.init_flag = true
end

quanta.run = function()
    qxpcall(quanta_update, "quanta_update error: %s")
end
