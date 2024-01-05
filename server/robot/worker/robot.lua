--robot.lua
import("feature/worker.lua")

quanta.startup(function()
    import("robot/worker/robot_worker.lua")
end)
