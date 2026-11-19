-- log_test.lua

local sformat   = string.format

local TestCase = import("test/case.lua")
local LogTest = class(TestCase)

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
end

return LogTest
