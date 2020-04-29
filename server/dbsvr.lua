--dbsvr.lua
import("quanta.lua")

local log_info      = logger.info
local hxpcall       = quanta.xpcall
local quanta_update = quanta.update

if not quanta.init_flag then
    local opts =
    {
        index   = 1,        --instance index
        log     = "dbsvr",  --log file: router
    }
    --初始化quanta
    quanta.init("dbsvr", opts)

    import("kernel/store/mongo_mgr.lua")

    log_info("dbsvr %d now startup!", quanta.id)
    quanta.init_flag = true
end

quanta.run = function()
    hxpcall(quanta_update, "quanta_update error: %s")
end
