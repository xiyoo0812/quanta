#!./quanta
import("kernel.lua")

quanta.startup(function()
    --初始化monitor
    import("monitor/monitor_mgr.lua")
    import("monitor/hotfix_mgr.lua")
end)
