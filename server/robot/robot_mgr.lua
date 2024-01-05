-- robot_mgr.lua
import("robot/msg_mgr.lua")
import("kernel/protobuf_mgr.lua")

local log_debug     = logger.debug

local thread_mgr    = quanta.get("thread_mgr")

local Robot         = import("robot/robot.lua")

local RobotMgr = singleton()
local prop = property(RobotMgr)
prop:reader("robot_list", {})   --robot_list

function RobotMgr:__init()
end

function RobotMgr:update()
    for _, robot in pairs(self.robot_list) do
        thread_mgr:fork(function()
            robot:update()
        end)
    end
end

--停止脚本，上报内容
function RobotMgr:stop_robot()
    for open_id, robot in pairs(self.robot_list) do
        robot:stop_script()
        self.robot_list[open_id] = nil
    end
end

-- setup
function RobotMgr:create_robot(ip, port, open_id)
    log_debug("[RobotMgr][create_robot]: {}:{} {}", ip, port, open_id)
    local robot = Robot()
    robot:set_ip(ip)
    robot:set_port(port)
    robot:set_open_id(open_id)
    self.robot_list[open_id] = robot
    return robot
end

function RobotMgr:get_robot(open_id)
    return self.robot_list[open_id]
end

function RobotMgr:destory_robot(open_id)
    local robot = self.robot_list[open_id]
    if robot then
        robot:logout_server()
        self.robot_list[open_id] = nil
        return { code = 0, msg = "success" }
    end
    return { code = -1, msg = "robot not exist" }
end

function RobotMgr:get_index_robot(index)
    return self.robot_list[index]
end

quanta.robot_mgr = RobotMgr()

return RobotMgr
