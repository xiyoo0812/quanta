--robot_worker.lua
import("feature/worker.lua")
import("robot/robot_mgr.lua")
import("network/http_client.lua")

local mceil         = math.ceil
local qmax          = qmath.max
local tinsert       = table.insert
local sformat       = string.format
local log_debug     = logger.debug
local lnow          = timer.now
local ltime         = timer.time
local lclock_ms     = timer.clock_ms

local timer_mgr     = quanta.get("timer_mgr")
local robot_mgr     = quanta.get("robot_mgr")
local event_mgr     = quanta.get("event_mgr")
local http_client   = quanta.get("http_client")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local ROBOT_ADDR    = environ.get("QUANTA_ROBOT_ADDR")

--30ms 一个槽位
local SLOT_TIME     = 30

local RobotWorker = singleton()
local prop = property(RobotWorker)
prop:reader("review", {})
prop:reader("watch_cmds", {})

function RobotWorker:__init()
    --task监听
    event_mgr:add_listener(self, "stop_robot_task")
    event_mgr:add_listener(self, "startup_robot_task")
    event_mgr:add_listener(self, "on_watch_message")
    --协议hook
    event_mgr:add_trigger(self, "on_recv_message")
    event_mgr:add_trigger(self, "on_error_message")
    event_mgr:register_hook(self, "on_ccmd_send", "on_message_hook")
    --初始化参数
    self.review.samples = {}
    self.review.child = quanta.title
    self.review.client = quanta.index
    self.review.task_id = environ.get("QUANTA_TASK_ID")
end

-- 启动机器人任务
-- rate: 单个机器人活动速率：多少毫秒发一次消息
function RobotWorker:startup_robot_task(start_open_id, num, ip, port, start_time, conf)
    log_debug("[RobotWorker][startup_robot_task] addr:{}:{} start_time:{}, num:{} conf:{}", ip, port, start_time, num, conf)
    --计算槽位，30ms一个槽位
    local slot = mceil(conf.rate / SLOT_TIME)
    --计算所有机器人对表时间
    local diff_time = start_time - quanta.now
    local period = 1000 * (qmax(diff_time, 1))
    for i = 1, num do
        local open_id_no = start_open_id + i
        local open_id = sformat("test_%d", open_id_no)
        local robot = robot_mgr:create_robot(ip, port, open_id)
        --计算机器人启动延时
        local slottime = (open_id_no % slot) * SLOT_TIME
        log_debug("[Robot][startup_robot_task] robot {} dalay {} action!", robot.open_id, slottime)
        timer_mgr:once(period + slottime * i, function()
            robot:load_case(conf.script, conf.rate)
        end)
    end
    --定时器启动
    timer_mgr:loop(50, function()
        robot_mgr:update()
    end)
    --定时器汇报
    timer_mgr:loop(5000, function()
        self:revicw_task()
    end)
end

--停止机器人
function RobotWorker:stop_robot_task()
    log_debug("[RobotWorker][stop_robot_task]")
    robot_mgr:stop_robot()
end

--观察消息
function RobotWorker:on_watch_message(cmd_name)
    local cmd_id = protobuf_mgr:msg_id(cmd_name)
    log_debug("[RobotWorker][on_watch_message] watch cmd {}-{}", cmd_id, cmd_name)
    self.watch_cmds[cmd_id] = true
end

--send hook
function RobotWorker:on_ccmd_send(hook, cmd_id)
    local now_ms, btime = ltime()
    hook:register(function()
        self:review_command(cmd_id, now_ms, lclock_ms() - btime)
    end)
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

function RobotWorker:revicw_task()
    http_client:call_post(ROBOT_ADDR, self.review)
    self.review.errors = nil
    self.review.samples = {}
end

quanta.robot_worker = RobotWorker()
