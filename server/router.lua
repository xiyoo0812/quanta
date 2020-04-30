--router.lua
import("kernel.lua")

local log_info      = logger.info
local hxpcall       = quanta.xpcall
local quanta_update = quanta.update

if not quanta.init_flag then
    local opts =
    {
        index   = 1,                --instance index
        log     = "router",         --log file: router.1
    }
    --初始化quanta
    quanta.init("router", opts)
    import("kernel/router/server_mgr.lua")

    log_info("routor %d now startup!", quanta.id)
    quanta.init_flag = true
end

quanta.run = function()
    hxpcall(quanta_update, "quanta_update error: %s")
end
