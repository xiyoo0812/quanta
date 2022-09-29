--report_mgr.lua
local ltimer        = require("ltimer")
local lnow_ms       = ltimer.now_ms
local mhuge         = math.huge
local tunpack       = table.unpack
local sformat       = string.format
local log_info      = logger.info

local robot_mgr     = quanta.get("robot_mgr")

--关键事件配置
local key_report_config = {
    ["login_account_success"]   = {
        --entry, key_event
        { "login_account_entry", "login_account_time" },
    },
    ["login_lobby_success"] = {
        { "login_account_entry", "login_time" },
        { "login_lobby_entry", "login_lobby_time" },
    }
}

local ReportMgr = singleton()
function ReportMgr:__init()
    -- 汇总数据
    self.robot_datas  = {}
    self.report_datas = {}
    -- 需要统计的总数量
    self.count = robot_mgr:get_count()
end

--机器人上报
function ReportMgr:robot_report(index, event, ...)
    local robot_data = self.robot_datas[index]
    if not robot_data then
        robot_data              = {}
        self.robot_datas[index] = robot_data
    end
    if robot_data[event] then
        --防止重复上报
        return
    end
    local now_ms = lnow_ms()
    robot_data[event] = { args = { ... }, tick = now_ms }
    --处理关键事件
    for _, report in pairs(key_report_config[event] or {}) do
        local entry_event, key_event = tunpack(report)
        if robot_data[entry_event] then
            local time = now_ms - robot_data[entry_event].tick
            self:report_key_event(key_event, time)
        end
    end
end

--处理关键事件
function ReportMgr:report_key_event(key_event, time)
    local report_data = self.report_datas[key_event]
    if not report_data then
        report_data                  = {
            number     = 0,
            max_time   = 0,
            total_time = 0,
            min_time   = mhuge,
            total      = self.count,
        }
        self.report_datas[key_event] = report_data
    end
    report_data.number     = report_data.number + 1
    report_data.total_time = report_data.total_time + time
    if time > report_data.max_time then
        report_data.max_time = time
    end
    if time < report_data.min_time then
        report_data.min_time = time
    end
    if report_data.number == self.count then
        self:dump_event(key_event, report_data)
    end
end

function ReportMgr:dump_event(event, data)
    local avg_time = data.total_time / data.number
    log_info("%s=>avg:%.2fms, min:%dms, max:%dms, succ:%d/%d", event, avg_time, data.min_time, data.max_time, data.number, data.total)
end

function ReportMgr:dump(whole)
    log_info("hive robots reports dump:")
    log_info("----------------------------------------------------")
    for event, data in pairs(self.report_datas) do
        self:dump_event(event, data)
    end
    log_info("----------------------------------------------------")
    if whole then
        log_info("hive robots details dump:")
        log_info("----------------------------------------------------")
        for index, robot_data in pairs(self.robot_datas) do
            local output = ""
            for event, data in pairs(robot_data) do
                output = sformat("%s %s=%.3f", output, event, data.tick / 1000)
            end
            log_info("robot-%s=>%s", index, output)
        end
        log_info("----------------------------------------------------")
    end
end

quanta.report_mgr = ReportMgr()

return ReportMgr
