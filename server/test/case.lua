--case.lua
local log_err       = logger.err
local log_dump      = logger.dump
local sformat       = string.format
local debug_getinfo = debug.getinfo

local TestCase = class()
local prop = property(TestCase)
prop:reader("name", "test")         --用例名
prop:reader("addr", nil)            --目标地址(mysql://... / http://... / 本地文件路径, 由注册表传入)
prop:reader("pass", 0)              --通过数
prop:reader("fail", 0)              --失败数
prop:reader("checks", 0)            --断言总数
prop:reader("failures", {})         --失败明细列表({name, line, res, err})
prop:reader("started", 0)           --开始时间(ms)
prop:reader("cost", 0)              --耗时(ms)

function TestCase:__init(name, addr)
    if name then
        self.name = name
    end
    self.addr = addr
end

local function report_line()
    local level = 2
    while level <= 16 do
        local info = debug_getinfo(level, "Sl")
        if not info then
            break
        end
        local src = info.short_src or ""
        if not src:find("case.lua", 1, true) and info.currentline and info.currentline > 0 then
            return info.currentline
        end
        level = level + 1
    end
    return 0
end

function TestCase:report(name, ok, res, err)
    self.checks = self.checks + 1
    if ok then
        self.pass = self.pass + 1
        log_dump("[TestCase][{}][OK] {}: {}", self.name, name, res)
    else
        self.fail = self.fail + 1
        local line = report_line()
        self.failures[#self.failures + 1] = { name = name, line = line, res = res, err = err }
        log_err("[TestCase][{}][FAIL] {} (line {}): res={}, err={}", self.name, name, line, res, err)
    end
    return ok
end

function TestCase:check_equal(name, actual, expect)
    return self:report(name, actual == expect, actual, sformat("expect: %s", expect))
end

function TestCase:check_true(name, value, err)
    return self:report(name, value and true or false, value, err)
end

function TestCase:call(title, func)
    local ok, err = pcall(func)
    if not ok then
        log_err("[TestCase][call] {} case {} error: {}", title, self.name, err)
    end
    return ok
end

function TestCase:execute(suite)
    self.started = quanta.clock_ms
    local done = self:call("setup/run", function()
        self:setup()
        self:run()
    end)
    local cleaned = self:call("teardown", function()
        self:teardown()
    end)
    self.cost = quanta.clock_ms - self.started
    if not done then
        self:report("case setup/run", false, "exception", "see error log above")
    end
    if not cleaned then
        self:report("case teardown", false, "exception", "see error log above")
    end
    suite:on_case_finish(self)
end

-- 子类实现
------------------------------------------------
function TestCase:setup()
end

function TestCase:teardown()
end

function TestCase:run()
end

return TestCase
