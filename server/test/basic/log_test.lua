-- log_test.lua

local sformat   = string.format
local log_dump  = logger.dump

local TestCase = import("test/case.lua")
local LogTest = class(TestCase)

--基准辅助: 计时用 timer.clock_ms() 实时值(quanta.clock_ms 是每帧缓存值, 不适合微基准)
local LOOPS       = 200000   --常规场景迭代次数
local LOOPS_HEAVY = 50000    --table 序列化较重, 降低次数

local function bench(loops, func)
    local t = timer.clock_ms()
    for i = 1, loops do
        func(i)
    end
    return timer.clock_ms() - t
end

local function perf_ratio(a, b)
    return b > 0 and sformat("%.2fx", a / b) or "n/a"
end

--自定义 monitor: 收集 collect_log 调用
local function make_monitor()
    local m = { count = 0, last_msg = nil, last_lvl = nil }
    function m:collect_log(msg, lvl_name)
        self.count = self.count + 1
        self.last_msg = msg
        self.last_lvl = lvl_name
    end
    return m
end

function LogTest:teardown()
    if self.monitor then
        logger.remove_monitor(self.monitor)
        self.monitor = nil
    end
    --恢复日志级别到 info, 避免影响后续用例
    logger.filter(log.LOG_LEVEL.DEBUG)
end

function LogTest:run()
    ------------------------------------------------------------------
    --1. log.format: {} 占位格式化(核心可断言功能)
    ------------------------------------------------------------------
    self:report("format no args", log.format("plain") == "plain", log.format("plain"), "plain")
    self:report("format one arg", log.format("val={}", 42) == "val=42", log.format("val={}", 42), "val=42")
    self:report("format multi args", log.format("{}/{}/{}", 1, "s", 3.5) == "1/s/3.5",
        log.format("{}/{}/{}", 1, "s", 3.5), "1/s/3.5")
    self:report("format table", type(log.format("t={}", { a = 1 })) == "string"
        and log.format("t={}", { a = 1 }):find("a") ~= nil, log.format("t={}", { a = 1 }), "contains a")
    self:report("format bool", log.format("b={}", true) == "b=true", log.format("b={}", true), "b=true")

    ------------------------------------------------------------------
    --2. LOG_LEVEL / LOG_FLAG 枚举存在且为数值
    ------------------------------------------------------------------
    local levels = { "INFO", "WARN", "DUMP", "DEBUG", "ERROR", "FATAL" }
    local lv_ok = true
    for _, name in ipairs(levels) do
        if type(log.LOG_LEVEL[name]) ~= "number" then lv_ok = false end
    end
    self:report("LOG_LEVEL enum", lv_ok, log.LOG_LEVEL, "all numbers")
    local flags = { "NULL", "FORMAT", "PRETTY", "MONITOR" }
    local fl_ok = true
    for _, name in ipairs(flags) do
        if type(log.LOG_FLAG[name]) ~= "number" then fl_ok = false end
    end
    self:report("LOG_FLAG enum", fl_ok, log.LOG_FLAG, "all numbers")
    self:report("LOG_LEVEL distinct", log.LOG_LEVEL.INFO ~= log.LOG_LEVEL.ERROR, true, "distinct")

    ------------------------------------------------------------------
    --3. logger 各级别函数可安全调用(格式化正确时不抛错)
    ------------------------------------------------------------------
    --logger 表只注册 LOG_OPTIONS 中的级别(fatal/debug/info/warn/err/dump), 没有 trace/print
    local levels_to_test = { "debug", "info", "warn", "err", "fatal", "dump" }
    local all_ok, first_err = true, nil
    for _, name in ipairs(levels_to_test) do
        if type(logger[name]) == "function" then
            local ok, err = pcall(logger[name], "[LOG_TEST] level {} ok", name)
            if not ok and not first_err then all_ok, first_err = false, tostring(err) end
        elseif not first_err then
            all_ok, first_err = false, "missing logger." .. name
        end
    end
    self:report("logger levels callable", all_ok, first_err or "all ok", "no exception")

    ------------------------------------------------------------------
    --4. logfeature: 创建带 feature 名的日志器并输出
    ------------------------------------------------------------------
    local fok, ferr = pcall(function()
        local ldebug = logfeature.debug("log_test_feature")
        ldebug("[LOG_TEST] feature debug {}", 1)
    end)
    self:report("logfeature.debug", fok == true, ferr, "no exception")
    local d_ok, d_err = pcall(function()
        local ldump = logfeature.dump("log_test_feature2")
        ldump("[LOG_TEST] feature dump {}", { k = 1 })
    end)
    self:report("logfeature.dump", d_ok == true, d_err, "no exception")

    ------------------------------------------------------------------
    --5. filter / is_filter: 过滤级别切换
    ------------------------------------------------------------------
    logger.filter(log.LOG_LEVEL.WARN)
    self:report("filter WARN hides DEBUG", log.is_filter(log.LOG_LEVEL.DEBUG) == true,
        log.is_filter(log.LOG_LEVEL.DEBUG), "true")
    self:report("filter WARN keeps ERROR", log.is_filter(log.LOG_LEVEL.ERROR) == false,
        log.is_filter(log.LOG_LEVEL.ERROR), "false")
    logger.filter(log.LOG_LEVEL.INFO)

    ------------------------------------------------------------------
    --6. monitor: 注册后 logger.info 触发 collect_log, 移除后不再触发
    ------------------------------------------------------------------
    local mon = make_monitor()
    self.monitor = mon
    logger.add_monitor(mon, log.LOG_LEVEL.INFO)
    logger.info("[LOG_TEST] monitor message {}", "hello")
    self:report("monitor received", mon.count >= 1, mon.count, ">=1")
    self:report("monitor lvl name", mon.last_lvl == "info", mon.last_lvl, "info")
    logger.remove_monitor(mon)
    local after_remove = mon.count
    logger.info("[LOG_TEST] after remove monitor")
    self:report("monitor removed", mon.count == after_remove, sformat("{}/{}", after_remove, mon.count), "stable")

    ------------------------------------------------------------------
    --7. 性能基准: log.format (C++ lualog) vs string.format (Lua 标准库)
    --   以输出对比数据为主, 断言仅保证被测量调用正常执行
    ------------------------------------------------------------------
    --预热: 排除首次调用/懒加载开销
    for i = 1, 1000 do
        log.format("{}", i)
        sformat("%s", i)
    end
    --7a. 单整数
    local lms = bench(LOOPS, function(i) return log.format("{}", i) end)
    local sms = bench(LOOPS, function(i) return sformat("%s", i) end)
    self:report("perf int both callable", lms >= 0 and sms >= 0,
        sformat("log=%dms str=%dms", lms, sms), ">=0")
    log_dump("[PERF][int]   log.format={}ms  string.format={}ms  ratio={}", lms, sms, perf_ratio(lms, sms))
    --7b. 三参数混合
    lms = bench(LOOPS, function(i) return log.format("{}/{}/{}", i, "s", 3.5) end)
    sms = bench(LOOPS, function(i) return sformat("%s/%s/%s", i, "s", 3.5) end)
    self:report("perf multi both callable", lms >= 0 and sms >= 0,
        sformat("log=%dms str=%dms", lms, sms), ">=0")
    log_dump("[PERF][multi] log.format={}ms  string.format={}ms  ratio={}", lms, sms, perf_ratio(lms, sms))
    --7c. table 序列化(log.format 触发 C++ serialize, string.format 走 tostring)
    local t = { a = 1, b = "x", c = { 1, 2, 3 } }
    lms = bench(LOOPS_HEAVY, function() return log.format("{}", t) end)
    sms = bench(LOOPS_HEAVY, function() return sformat("%s", t) end)
    self:report("perf table both callable", lms >= 0 and sms >= 0,
        sformat("log=%dms str=%dms", lms, sms), ">=0")
    log_dump("[PERF][table] log.format={}ms  string.format={}ms  ratio={}", lms, sms, perf_ratio(lms, sms))
end

return LogTest
