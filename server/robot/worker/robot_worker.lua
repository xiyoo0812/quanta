--robot_worker.lua
import("feature/worker.lua")
import("robot/robot_mgr.lua")

local mceil         = math.ceil
local qmax          = qmath.max
local tinsert       = table.insert
local sformat       = string.format
local log_debug     = logger.debug

local timer_mgr     = quanta.get("timer_mgr")
local robot_mgr     = quanta.get("robot_mgr")
local event_mgr     = quanta.get("event_mgr")

--30ms 一个槽位
local SLOT_TIME     = 30

local RobotWorker = singleton()
local prop = property(RobotWorker)
prop:reader("watch_cmds", {})
prop:reader("error_infos", {})
prop:reader("failed_nums", {})
prop:reader("success_nums", {})

function RobotWorker:__init()
    event_mgr:add_listener(self, "startup_robot_task")
    event_mgr:add_listener(self, "stop_robot_task")
    event_mgr:add_listener(self, "on_call_message")
    event_mgr:add_listener(self, "on_watch_message")
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
    timer_mgr:loop(50, function()
        robot_mgr:update()
    end)
end

--停止机器人
function RobotWorker:stop_robot_task()
    log_debug("[RobotWorker][stop_robot_task]")
    robot_mgr:stop_robot()
end


function RobotWorker:on_watch_message(cmd_id)
    self.watch_cmds[cmd_id] = true
end

--信息统计
function RobotWorker:on_call_message(robot, cmd_id, ok, res)
    if not self.watch_cmds[cmd_id] then
        return
    end
    --统计成功计数
    if robot:check_callback(ok, res) then
        local old_count = self.success_nums[cmd_id] or 0
        self.success_nums[cmd_id] = old_count + 1
        return
    end
    --统计失败计数
    local old_count = self.failed_nums[cmd_id] or 0
    self.failed_nums[cmd_id] = old_count + 1
    --统计错误信息
    if not self.error_infos[cmd_id] then
        self.error_infos[cmd_id] = {}
    end
    tinsert(self.error_infos[cmd_id], {robot.open_id, robot.player_id, res})
end

quanta.robot_worker = RobotWorker()
