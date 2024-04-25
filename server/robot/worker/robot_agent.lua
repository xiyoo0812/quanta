--robot_agent.lua
import("network/http_client.lua")

local mceil         = math.ceil
local log_err       = logger.err
local log_debug     = logger.debug
local sformat       = string.format

local scheduler     = quanta.get("scheduler")
local timer_mgr     = quanta.get("timer_mgr")
local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local THREAD_ROBOT  = environ.number("QUANTA_THREAD_ROBOT", 2)
local ROBOT_ENTRY   = environ.get("QUANTA_ROBOT_ENTRY")

local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_3_MS   = quanta.enum("PeriodTime", "SECOND_3_MS")

local RobotAgent    = singleton()

function RobotAgent:__init()
    -- 准备开启
    thread_mgr:success_call(SECOND_MS, function()
        return self:load_task()
    end, SECOND_MS)
end

function RobotAgent:startup(conf, task_id, task_conf)
    local all_count = task_conf.count
    local start_open_id = task_conf.start_open_id
    local worker_num = mceil(all_count / THREAD_ROBOT)
    for i = 1, worker_num do
        --启动机器人线程
        local name = sformat("robot_%s", i)
        scheduler:startup(name, ROBOT_ENTRY)
        --发布任务
        event_mgr:fire_second(function()
            local num = all_count >= THREAD_ROBOT and THREAD_ROBOT or all_count
            scheduler:send(name, "startup_robot_task", start_open_id, num, conf.ip, conf.port, conf.start_time, task_conf)
            start_open_id = start_open_id + THREAD_ROBOT
            all_count = all_count - THREAD_ROBOT
        end)
    end
    --定时器停止
    timer_mgr:once(conf.time, function()
        --停止任务
        scheduler:broadcast("stop_robot_task")
        --退出进程
        timer_mgr:once(SECOND_3_MS, function()
            --通知woker退出
            scheduler:quit()
            signal.quit()
        end)
    end)
end

function RobotAgent:load_task()
    local task_id = environ.get("QUANTA_TASK_ID")
    local conf = import(sformat("robot/tasks/%s.lua", task_id))
    if not conf then
        log_err("[RobotAgent][load_task] task {} config not exist", task_id)
        signal.quit()
        return false
    end
    log_debug("[RobotAgent][load_task] conf: {}", conf)
    local child_id = quanta.index
    local task_conf = conf.tasks[child_id]
    if not task_conf then
        log_err("[RobotAgent][load_task] task {} task config not exist", task_id)
        signal.quit()
        return false
    end
    self:startup(conf, task_id, task_conf)
    return true
end

quanta.robot_agent = RobotAgent()

return RobotAgent
