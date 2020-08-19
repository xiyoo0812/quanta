#!./quanta
import("kernel.lua")
local log_info      = logger.info
local qxpcall       = quanta.xpcall
local quanta_update = quanta.update

if not quanta.init_flag then
    local function startup()
        --初始化quanta
        quanta.init()
        --初始化cachesvr
        import("kernel/cache/cache_mgr.lua")
        log_info("cachesvr %d now startup!", quanta.id)
    end
    qxpcall(startup, "quanta startup error: %s")
    quanta.init_flag = true
end

quanta.run = function()
    qxpcall(quanta_update, "quanta_update error: %s")
end
