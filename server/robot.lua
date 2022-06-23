#!./quanta
import("kernel.lua")

quanta.startup(function()
    --初始化robot
    import("kernel/protobuf_mgr.lua")
    import("robot/report_mgr.lua")
    import("robot/robot_mgr.lua")
end)
