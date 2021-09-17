--proxy.lua
import("kernel.lua")
local log_info      = logger.info
local qxpcall_quit  = quanta.xpcall_quit

if not quanta.init_flag then
    local function startup()
        --初始化quanta
        quanta.init()
        --初始化proxy
        import("proxy/proxy_mgr.lua")
        log_info("proxy %d now startup!", quanta.id)
    end
    qxpcall_quit(startup, "quanta startup error: %s")
    quanta.init_flag = true
end
