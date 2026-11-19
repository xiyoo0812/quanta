--suite.lua
--测试套件: 编排所有用例, 全部完成后统一输出; 有失败输出 err, 全部成功输出 info
local log_err    = logger.err
local log_debug  = logger.debug
local log_dump   = logger.dump
local log_warn   = logger.warn
local log_info   = logger.info
local log_fatal  = logger.fatal

local thread_mgr = quanta.get("thread_mgr")
local TEST_TIMEOUT = environ.number("QUANTA_TEST_TIMEOUT", 120000)

local TestSuite = class()
local prop = property(TestSuite)
prop:reader("cases", {})        --已注册的用例对象
prop:reader("finished", 0)      --已完成数
prop:reader("reported", false)  --是否已汇总输出
prop:reader("started", 0)       --开始时间(ms)

function TestSuite:__init()
    self.cases = {}
    self.finished = 0
    self.reported = false
end

function TestSuite:add_case(case)
    self.cases[#self.cases + 1] = case
    return self
end

--并行启动所有用例; 每个用例内部可自由 sleep, 完成与否由 case:execute 回调
function TestSuite:run_all()
    local total = #self.cases
    if total == 0 then
        log_err("[SUITE] no case registered, nothing to run")
        return
    end
    self.started = quanta.clock_ms
    log_dump("------------------------------------------------------------------")
    log_warn("[SUITE] now start {} test case(s) ============", total)
    log_dump("------------------------------------------------------------------")
    --看门狗: 防止某用例死循环/卡死导致永不汇总(仅兜底, 正常路径不会触发)
    thread_mgr:fork(function()
        thread_mgr:sleep(TEST_TIMEOUT)
        if not self.reported then
            log_info("------------------------------------------------------------------")
            log_warn("[SUITE][TIMEOUT] only {}/{} cases finished, force report", self.finished, total)
            log_info("------------------------------------------------------------------")
            self:report_all(true)
        end
    end)
    for _, case in ipairs(self.cases) do
        thread_mgr:fork(function()
            log_info("------------------------------------------------------------------")
            log_debug("[CASE][{}] strat execute", case.name)
            log_info("------------------------------------------------------------------")
            case:execute(self)
        end)
    end
end

function TestSuite:on_case_finish(case)
    self.finished = self.finished + 1
    log_info("------------------------------------------------------------------")
    log_debug("[CASE][{}] finished: pass={}, fail={} ({}/{})",
        case.name, case.pass, case.fail, self.finished, #self.cases)
    log_info("------------------------------------------------------------------")
    if self.finished >= #self.cases and not self.reported then
        self:report_all(false)
    end
end

--所有用例结束后统一输出: 先逐用例汇总(pass/fail), 再逐条列出失败行为名+行号, 最后总体结果
--结果行统一用 dump: 会展开 table 参数, 且级别醒目(区别于 info 不展开表 / debug 白色不明显)
function TestSuite:report_all(timed_out)
    if self.reported then
        return
    end
    self.reported = true
    local cost = quanta.clock_ms - self.started
    local total_checks, total_pass, total_fail = 0, 0, 0
    --先累加各用例总数, 再输出 RESULT; 否则 total_fail 恒为 0 会误报 ALL PASSED
    for _, case in ipairs(self.cases) do
        total_checks = total_checks + case.checks
        total_pass = total_pass + case.pass
        total_fail = total_fail + case.fail
    end
    log_fatal("==================================================================")
    if total_fail == 0 and not timed_out then
        log_debug("[SUITE] RESULT: cases={}, checks={}, pass={}, fail={}, cost={}ms, ALL PASSED",
            #self.cases, total_checks, total_pass, total_fail, cost)
    else
        log_err("[SUITE] RESULT: cases={}, checks={}, pass={}, fail={}, cost={}ms, HAS FAILURE",
            #self.cases, total_checks, total_pass, total_fail, cost)
    end
    for _, case in ipairs(self.cases) do
        log_dump("------------------------------------------------------------------")
        log_debug("[CASE][{}] report: pass={}, fail={}, checks={}, cost={}ms",
            case.name, case.pass, case.fail, case.checks, case.cost)
        for _, failure in ipairs(case.failures) do
            log_err("[CASE][{}] fail: {} (line {}): res={}, err={}",
                case.name, failure.name, failure.line, failure.res, failure.err)
        end
        log_dump("------------------------------------------------------------------")
    end
    log_fatal("==================================================================")
end

return TestSuite
