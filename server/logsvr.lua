#!./hive
import("share/hive.lua")
local hive_update   = hive.update
local log_info      = logger.info
local hxpcall       = hive.xpcall

if not hive.init_flag then
    local confs =
    {
        index   = 1,            --instance index
        log     = "logagent",   --log file: router
    }

    --初始化hive
    hive.init("logagent", confs)

    import("logsvr/log_mgr.lua")

    log_info("logagent %d now startup!", hive.id)
    hive.init_flag = true
end

hive.run = function()
    hxpcall(hive_update, "hive_update error: %s")
end
