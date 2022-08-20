-- robot_mgr.lua
local lcrypt        = require("lcrypt")

local log_err       = logger.err
local log_debug     = logger.debug
local sformat       = string.format
local signalquit    = signal.quit
local env_addr      = environ.addr
local env_number    = environ.number
local guid_string   = lcrypt.guid_string

local timer_mgr     = quanta.get("timer_mgr")
local report_mgr    = quanta.get("report_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local node_factory  = quanta.get("node_factory")

local RRANDOM       = quanta.enum("RobotType", "RANDOM")
local RCOMPOSE      = quanta.enum("RobotType", "COMPOSE")
local RPLAYER       = quanta.enum("RobotType", "PLAYER")
local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")

local Robot         = import("robot/robot.lua")

local RobotMgr = singleton()
local prop = property(RobotMgr)
prop:accessor("robot_list", {})    --robot_list

function RobotMgr:__init()
    self:setup()
end

-- setup
function RobotMgr:setup()
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
    -- 配置上报管理器
    report_mgr:setup(robot_count)
    --启动定时器
    timer_mgr:once(SECOND_MS, function()
        -- 节点工厂初始化
        node_factory:load()
        -- 创建机器人
        for i = 1, robot_count do
            self:create_robot(ip, port, conf, i)
        end
    end)
end

-- setup
function RobotMgr:create_robot(ip, port, conf, index)
    log_debug("[RobotMgr][create_robot]: %s:%s %s(%s)", ip, port, index, conf)
    local robot = Robot(conf, index)
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

function RobotMgr:get_robot(index)
    return self.robot_list[index]
end

quanta.robot_mgr = RobotMgr()

return RobotMgr
