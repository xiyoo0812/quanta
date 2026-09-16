-- robot_mgr.lua
import("kernel/protobuf_mgr.lua")

local log_debug     = logger.debug

local Robot         = import("robot/robot.lua")

local RobotMgr = singleton()
local prop = property(RobotMgr)
prop:reader("robots", {})   --robots

function RobotMgr:__init()
end

--停止脚本，上报内容
function RobotMgr:stop_robot()
    for open_id, robot in pairs(self.robots) do
        robot:stop_case()
        self.robots[open_id] = nil
    end
end

-- setup
function RobotMgr:create_robot(ip, port, open_id)
    log_debug("[RobotMgr][create_robot]: {}:{} {}", ip, port, open_id)
    local robot = Robot(ip, port, open_id)
    self.robots[open_id] = robot
    return robot
end

function RobotMgr:get_robot(open_id)
    return self.robots[open_id]
end

function RobotMgr:destory_robot(open_id)
    local robot = self.robots[open_id]
    if robot then
        robot:destroy()
        self.robots[open_id] = nil
        return { code = 0, msg = "success" }
    end
    return { code = -1, msg = "robot not exist" }
end

quanta.robot_mgr = RobotMgr()

return RobotMgr
