#!./quanta
import("kernel.lua")

quanta.startup(function()
    --初始化robot
    import("kernel/protobuf_mgr.lua")
    import("robot/node_factory.lua")
    import("robot/report_mgr.lua")
    import("robot/robot_mgr.lua")
    --加载节点工厂
    import("robot/node/login_factory.lua")
end)
