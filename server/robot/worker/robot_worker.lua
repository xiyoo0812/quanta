--robot_worker.lua
import("robot/robot_mgr.lua")

local qmax          = qmath.max
local tinsert       = table.insert
local sformat       = string.format
local log_debug     = logger.debug
local lnow          = timer.now

local timer_mgr     = quanta.get("timer_mgr")
local robot_mgr     = quanta.get("robot_mgr")
local event_mgr     = quanta.get("event_mgr")

local http_client   = quanta.http_client()

local ROBOT_ADDR    = environ.get("QUANTA_ROBOT_ADDR")

--30ms 一个槽位
local SLOT_TIME     = 30

local RobotWorker = singleton()
local prop = property(RobotWorker)
prop:reader("review", {})
prop:reader("watch_cmds", {})

function RobotWorker:__init()
    --task监听
    event_mgr:add_listener(self, "run_robot_case")
    event_mgr:add_listener(self, "run_robot_node")
    event_mgr:add_listener(self, "fetch_robot_status")
    event_mgr:add_listener(self, "fetch_robot_messages")
    event_mgr:add_listener(self, "startup_robot_task")
    event_mgr:add_listener(self, "stop_robot_task")
    --协议hook
    event_mgr:add_listener(self, "on_recv_message")
    event_mgr:add_listener(self, "on_error_message")
    --初始化参数
    self.review.samples = {}
    self.review.child = quanta.title
    self.review.client = quanta.index
    self.review.task_id = environ.get("QUANTA_TASK_ID")
end

-- 启动机器人任务
-- hertz: 单个机器人活动速率：多少毫秒发一次消息
function RobotWorker:startup_robot_task(open_id, id, num, ip, port, time, case, hertz)
    log_debug("[RobotWorker][startup_robot_task] addr:{}:{} id:{} num:{} case:{} hertz:{}", ip, port, id, num, case, hertz)
    --计算所有机器人对表时间
    local diff_time = time - quanta.now
    local period = 1000 * (qmax(diff_time, 0))
    for i = 1, num do
        local open_id_no = id + i
        local real_open_id = sformat("%s_%d", open_id, open_id_no)
        local robot = robot_mgr:create_robot(ip, port, real_open_id, true)
        --计算机器人启动延时
        local slottime = i * SLOT_TIME
        log_debug("[Robot][startup_robot_task] robot {} dalay {} action!", robot.open_id, slottime)
        timer_mgr:once(period + slottime, function()
            robot:load_case(case, hertz)
        end)
    end
    --定时器汇报
    timer_mgr:loop(5000, function()
        self:review_task()
    end)
end

-- 运行机器人用例
function RobotWorker:run_robot_case(open_id, addr, port, body)
    log_debug("[RobotWorker][run_robot_case] addr:{}:{} open_id:{}", addr, port, open_id)
    local robot = robot_mgr:get_robot(open_id)
    if not robot then
        robot = robot_mgr:create_robot(addr, port, open_id)
    end
    local case = robot:create_case_by_data(body)
    if case then
        robot:startup(case)
    end
    return true
end

-- 运行机器人用例节点
function RobotWorker:run_robot_node(open_id, body)
    log_debug("[RobotWorker][run_robot_node] open_id:{}", open_id)
    local robot = robot_mgr:get_robot(open_id)
    if robot then
        robot:mount_node(body)
        return true
    end
    return false
end

-- 获取机器人状态
function RobotWorker:fetch_robot_status(open_id)
    local robot = robot_mgr:get_robot(open_id)
    if robot then
        return robot:get_status()
    end
    return nil
end

-- 获取机器人消息
function RobotWorker:fetch_robot_messages(open_id)
    local robot = robot_mgr:get_robot(open_id)
    if robot then
        return robot:fetch_messages()
    end
end

--停止机器人
function RobotWorker:stop_robot_task()
    log_debug("[RobotWorker][stop_robot_task]")
    robot_mgr:destory()
end

--发送汇报
function RobotWorker:review_command(cmd_id, now_ms, diff_time)
    local time = now_ms // 1000
    local time_samples = self.review.samples[time]
    if not time_samples then
        time_samples = { sendn = 0, failn = 0, recvn = 0, sends = {}, recvs = {}}
        self.review.samples[time] = time_samples
    end
    time_samples.sendn = time_samples.sendn + 1
    time_samples.recvn = time_samples.recvn + 1
    if self.watch_cmds[cmd_id] then
        local cmdsample = time_samples.sends[cmd_id]
        if not cmdsample then
            time_samples.sends[cmd_id] = { sendn = 1, failn = 0, maxt = diff_time, allt = diff_time, mint = diff_time }
            return
        end
        cmdsample.sendn = cmdsample.sendn + 1
        cmdsample.allt = cmdsample.allt + diff_time
        if diff_time > cmdsample.maxt then
            cmdsample.maxt = diff_time
        end
        if diff_time < cmdsample.mint then
            cmdsample.mint = diff_time
        end
    end
end

--接受统计
function RobotWorker:on_recv_message(cmd_id)
    local time = lnow()
    local time_samples = self.review.samples[time]
    if not time_samples then
        time_samples = { sendn = 0, failn = 0, recvn = 0, sends = {}, recvs = {}}
        self.review.samples[time] = time_samples
    end
    time_samples.recvn = time_samples.recvn + 1
    if self.watch_cmds[cmd_id] then
        local old_cnt = time_samples.recvs[cmd_id] or 0
        time_samples.recvs[cmd_id] = old_cnt + 1
    end
end

--错误统计
function RobotWorker:on_error_message(cmd_id, open_id, res)
    local time = lnow()
    local time_samples = self.review.samples[time]
    if not time_samples then
        time_samples = { sendn = 0, failn = 0, recvn = 0, sends = {}, recvs = {}}
        self.review.samples[time] = time_samples
    end
    time_samples.failn = time_samples.failn + 1
    if self.watch_cmds[cmd_id] then
        local cmdsample = time_samples.sends[cmd_id]
        if not cmdsample then
            return
        end
        cmdsample.failn = cmdsample.failn + 1
        if res then
            if not self.review.errors then
                self.review.errors = {}
            end
            if type(res) == "table" then
                tinsert(self.review.errors, { open_id = open_id, cmd_id = cmd_id, code = res.error_code, time = time })
            else
                tinsert(self.review.errors, { open_id = open_id, cmd_id = cmd_id, err = res, time = time })
            end
        end
    end
end

function RobotWorker:review_task()
    http_client:call_post(ROBOT_ADDR, self.review)
    self.review.errors = nil
    self.review.samples = {}
end

quanta.robot_worker = RobotWorker()
