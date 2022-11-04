-- robot_mgr.lua
local lcodec        = require("lcodec")

local log_err       = logger.err
local log_debug     = logger.debug
local sformat       = string.format
local signalquit    = signal.quit
local env_addr      = environ.addr
local env_number    = environ.number
local guid_string   = lcodec.guid_string

local timer_mgr     = quanta.get("timer_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local RRANDOM       = quanta.enum("RobotType", "RANDOM")
local RCOMPOSE      = quanta.enum("RobotType", "COMPOSE")
local RPLAYER       = quanta.enum("RobotType", "PLAYER")
local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")

local Robot         = import("robot/robot.lua")
local RobotBT       = import("robot/robot_bt.lua")

local RobotMgr = singleton()
local prop = property(RobotMgr)
prop:reader("count", 0)         --count
prop:reader("robot_list", {})   --robot_list

function RobotMgr:__init()
end

-- setup
function RobotMgr:load_robot()
    local index = quanta.index
    local config_mgr = quanta.get("config_mgr")
    local robot_db = config_mgr:init_table("robot", "index")
    local conf = robot_db:find_one(index)
    if not conf then
        log_err("[RobotMgr][setup] robot config(%s) is empty", index)
        signalquit()
        return
    end
    log_debug("[RobotMgr][setup] robot config(%s) is loading!", index)
    local ip, port = env_addr("QUANTA_ROBOT_ADDR")
    local robot_count = env_number("QUANTA_COUNT", conf.count)
    --指定账号模式，只能一个机器人
    if conf.openid_type == RPLAYER then
        robot_count = 1
    end
    self.count = robot_count
    --启动定时器
    timer_mgr:once(SECOND_MS, function()
        -- 创建机器人
        for i = 1, robot_count do
            self:create_robot_bt(ip, port, conf, i)
        end
    end)
end

-- setup
function RobotMgr:create_robot_bt(ip, port, conf, index)
    log_debug("[RobotMgr][create_robot_bt]: %s:%s %s(%s)", ip, port, index, conf)
    local robot = RobotBT(conf, index)
    if conf.openid_type == RRANDOM then
        robot:set_open_id(guid_string())
    elseif conf.openid_type == RCOMPOSE then
        robot:set_open_id(sformat("%s_%d", conf.open_id, index))
    else
        robot:set_open_id(conf.open_id)
    end
    robot:set_ip(ip)
    robot:set_port(port)
    robot:set_access_token(conf.access_token)

    thread_mgr:fork(function()
        while robot:is_running() do
            local sleep_ms = robot:update()
            if sleep_ms > 0 then
                thread_mgr:sleep(sleep_ms)
            end
        end
    end)
    self.robot_list[index] = robot
end

-- setup
function RobotMgr:create_robot(ip, port, open_id, passwd)
    log_debug("[RobotMgr][create_robot]: %s:%s %s(%s)", ip, port, open_id, passwd)
    local robot = Robot()
    robot:set_ip(ip)
    robot:set_port(port)
    robot:set_open_id(open_id)
    robot:set_access_token(passwd)
    self.robot_list[open_id] = robot
    local ok, res = robot:login_server()
    return { code = ok and 0 or -1, msg = res }
end

function RobotMgr:get_robot(open_id)
    return self.robot_list[open_id]
end

function RobotMgr:destory_robot(open_id)
    local robot = self.robot_list[open_id]
    if robot then
        local ok, res = robot:logout_server()
        return { code = ok and 0 or -1, msg = res }
    end
    return { code = -1, msg = "robot not exist" }
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

function RobotMgr:get_accord_message(open_id)
    local robot = self.robot_list[open_id]
    if robot then
        local res = { code = 0, msg = robot:get_messages() }
        return res
    end
    return { code = -1, msg = "robot not exist" }
end

function RobotMgr:run_accord_message(open_id, cmd_id, data)
    local robot = self.robot_list[open_id]
    if robot then
        local ok, res = robot:call(cmd_id, data)
        return { code = ok and 0 or -1, msg = res }
    end
    return { code = -1, msg = "robot not exist" }
end

function RobotMgr:run_accord_messages(open_id, cmd_datas)
    local robot = self.robot_list[open_id]
    if robot then
        for _, info in ipairs(cmd_datas) do
            local ok, res = robot:call(info.id, info.args)
            if not ok then
                return { code = -1, msg = res }
            end
        end
        return { code = 0, msg = "success" }
    end
    return { code = -1, msg = "robot not exist" }
end

function RobotMgr:get_index_robot(index)
    return self.robot_list[index]
end

quanta.robot_mgr = RobotMgr()

return RobotMgr
