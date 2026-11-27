--case.lua
local log_err       = logger.err
local log_dump      = logger.dump
local sformat       = string.format
local debug_getinfo = debug.getinfo

local TestCase = class()

local prop = property(TestCase)
prop:reader("name", "test")         --用例名
prop:reader("temp_dir", nil)        --用例在 bin/temp 下的基础子目录名(子类定义)
prop:reader("cleanup", true)        --是否在用例执行后清理中间产物(由构造函数传入)
prop:reader("addr", nil)            --目标地址(mysql://... / http://... / 本地文件路径, 由注册表传入)
prop:reader("pass", 0)              --通过数
prop:reader("fail", 0)              --失败数
prop:reader("checks", 0)            --断言总数
prop:reader("failures", {})         --失败明细列表({name, line, res, err})
prop:reader("started", 0)           --开始时间(ms)
prop:reader("cost", 0)              --耗时(ms)

function TestCase:__init(name, addr, cleanup)
    if name then
        self.name = name
    end
    self.addr = addr
    if cleanup ~= nil then
        self.cleanup = cleanup
    end
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

--临时目录工具: 子类只需定义 self.temp_dir(在 bin/temp 下的子目录名),
--基类统一负责拼绝对路径、建目录、清理, 避免每个用例重复实现
--返回用例的临时根目录(绝对路径, bin/temp/<temp_dir>)
--首次调用时固定下来, 避免测试内 chdir 后重复解析相对路径导致路径变化
function TestCase:temp_root()
    if not self._temp_root then
        local name = self.temp_dir or self.name
        self._temp_root = tostring(stdfs.absolute(stdfs.append("./temp", name)))
    end
    return self._temp_root
end

--拼接临时路径: self:temp_path("a", "b.txt") -> bin/temp/<temp_dir>/a/b.txt
function TestCase:temp_path(...)
    local p = self:temp_root()
    for _, part in ipairs({ ... }) do
        p = stdfs.append(p, part)
    end
    return tostring(p)
end

--清空并重建临时根目录
function TestCase:prepare_temp()
    local root = self:temp_root()
    if stdfs.exists(root) then
        stdfs.remove(root, true)
    end
    stdfs.mkdir(root)
    return root
end

--删除临时根目录
function TestCase:cleanup_temp()
    local root = self:temp_root()
    if stdfs.exists(root) then
        stdfs.remove(root, true)
    end
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
    if self.cleanup then
        local cleaned = self:call("cleanup", function()
            self:on_cleanup()
        end)
        if not cleaned then
            self:report("case cleanup", false, "exception", "see error log above")
        end
    end
    self.cost = quanta.clock_ms - self.started
    if not done then
        self:report("case setup/run", false, "exception", "see error log above")
    end
    suite:on_case_finish(self)
end

-- 子类实现
------------------------------------------------
function TestCase:setup()
end

function TestCase:on_cleanup()
end

function TestCase:run()
end

return TestCase
