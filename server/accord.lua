#!./quanta
import("kernel.lua")

quanta.startup(function()
    import("kernel/protobuf_mgr.lua")
    import("robot/node_factory.lua")
    import("robot/robot_mgr.lua")
    import("robot/accord_mgr.lua")
end)
