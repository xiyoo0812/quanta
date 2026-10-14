-- robot_mgr.lua
import("kernel/protobuf_mgr.lua")

local log_debug     = logger.debug
local jdecode       = json.decode

local RobotMgr = singleton()
local prop = property(RobotMgr)
prop:reader("cases", {})   --cases
prop:reader("robots", {})   --robots

function RobotMgr:__init()
end

function RobotMgr:update_case(body)
    local data = jdecode(body, true)
    self.cases[data.name] = { name = data.name, root = data.root, nodes = data.nodes }
end

function RobotMgr:delete_case(name)
    self.cases[name] = nil
end

function RobotMgr:get_case(name)
    return self.cases[name]
end

-- setup
function RobotMgr:create_robot(open_id, params, press)
    log_debug("[RobotMgr][create_robot]: {}:{}", open_id, params)
    local Robot = import("robot/robot.lua")
    local robot = Robot(open_id, params, press)
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
    end
end

--停止脚本，上报内容
function RobotMgr:destory()
    for open_id, robot in pairs(self.robots) do
        robot:destroy()
    end
    self.robots = {}
end

quanta.robot_mgr = RobotMgr()

return RobotMgr
