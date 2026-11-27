-- profile_test.lua
local sformat       = string.format
local log_debug     = logger.debug

local TestCase      = import("test/case.lua")
local ProfileTest   = class(TestCase)

function ProfileTest:__init(name, addr, cleanup)
    self.temp_dir = "quanta_profile_test"
end

--测试内强制加载 lprofile. 已加载时 package.loaded 直接复用, 不会重复 hook
local function load_prof()
    local ok, prof = pcall(require, "lprofile")
    if not ok or type(prof) ~= "table" then
        prof = _G.profile
    end
    return prof
end

--dump 输出: 按原生 perfdump 风格打印一次统计表, 用 title 标记是哪段负载。
--关键: profile.dump() 内部自带 m_evals.clear(), 一批数据只能 dump 一次。
local PROFDUMP = "{:<25} {:^9} {:^9} {:^9} {:^12} {:^8} {:^10} {:^12} [{}]{}:{}"
local HEADER   = "{:<25} {:^9} {:^9} {:^9} {:^12} {:^8} {:^10} {:^12} {:<10}"
local function dump_profile(prof, title, top)
    prof.disable()
    local evals = prof.dump(top or 20)
    log_debug("[PERF][{}] profile stat:", title)
    log_debug("--------------------------------------------------------------------------------------------------------------------------------")
    log_debug(HEADER, "name", "avg", "min", "max", "all", "per(%)", "suspend", "count", "source")
    log_debug("--------------------------------------------------------------------------------------------------------------------------------")
    for _, ev in pairs(evals) do
        log_debug(PROFDUMP, ev.name, ev.avg, ev.min, ev.max, ev.all, ev.per, ev.suspend, ev.count, ev.flag, ev.src, ev.line)
    end
    log_debug("--------------------------------------------------------------------------------------------------------------------------------")
    return evals
end

--执行一段可被采样的工作
local function busy_work(n)
    local s = 0
    for i = 1, n do s = s + i end
    local t = {}
    for i = 1, 100 do t[i] = tostring(s + i) end
    return s, t
end

function ProfileTest:setup()
    self:prepare_temp()
    self.svg_path = self:temp_path("quanta_profile_test.svg")
end

function ProfileTest:on_cleanup()
    if self.prof then
        pcall(function() self.prof.disable() end)
    end
    self:cleanup_temp()
end

function ProfileTest:run()
    ------------------------------------------------------------------
    --0. 测试内强制加载 lprofile 并安装 hook(不依赖 QUANTA_PROFILE 配置)
    ------------------------------------------------------------------
    local prof = load_prof()
    self.prof = prof
    self:report("lprofile loaded", type(prof) == "table", type(prof), "table")
    if type(prof) ~= "table" then return end
    local hok, herr = pcall(function() prof.hook() end)
    self:report("profile hook installed", hok == true, herr, "no exception")

    ------------------------------------------------------------------
    --1. 底层 profile 表接口齐全
    ------------------------------------------------------------------
    local prof_api = { "enable", "disable", "hook", "watch", "dump", "flame", "ignore", "ignore_file", "ignore_func" }
    local prof_ok = true
    for _, name in ipairs(prof_api) do
        if type(prof[name]) ~= "function" then prof_ok = false end
    end
    self:report("profile lib api exists", prof_ok, prof_ok and "all" or "missing", "all functions")

    ------------------------------------------------------------------
    --2. 常规负载: busy_work x50 -> perfdump 统计表
    ------------------------------------------------------------------
    local eok, eerr = pcall(function()
        prof.enable()
        for _ = 1, 50 do busy_work(200) end
    end)
    self:report("profile busy_work workload", eok == true, eerr, "no exception")
    local dump_ok, dump_res = pcall(function()
        return dump_profile(prof, "busy_work", 20)
    end)
    self:report("profile dump callable", dump_ok == true, dump_res, "no exception")
    self:report("profile dump returns table", type(dump_res) == "table", type(dump_res), "table")
    if type(dump_res) == "table" then
        local has_fields = true
        for _, ev in pairs(dump_res) do
            if type(ev) ~= "table" or ev.name == nil or ev.count == nil then has_fields = false end
            break
        end
        self:report("profile dump entry fields", has_fields, has_fields and "ok" or "bad", "name/count present")
    end

    ------------------------------------------------------------------
    --3. watch / ignore 配置接口可调用
    ------------------------------------------------------------------
    local wok, werr = pcall(function()
        prof.watch("busy_work")
        prof.ignore_func("busy_work")
        prof.ignore_file("some_file.lua")
    end)
    self:report("profile watch/ignore callable", wok == true, werr, "no exception")

    ------------------------------------------------------------------
    --4. 典型样例: 协程 + sleep + 嵌套调用(master 原有 index==2 样例)
    --   profile.hook 已接管 coroutine.create, 协程内调用可被采样;
    --   timer.sleep 属于挂起等待, 会体现在 suspend 列。
    ------------------------------------------------------------------
    local function sleep_work(ms)
        timer.sleep(ms)
    end
    local function nested()
        log_debug("[PERF][coroutine] nested-1")
        coroutine.yield()
        sleep_work(50)
        log_debug("[PERF][coroutine] nested-2")
    end
    local co_ok, co_err = pcall(function()
        prof.enable()
        local co = coroutine.create(function() nested() end)
        coroutine.resume(co)      --执行到 yield
        sleep_work(30)            --主线程 sleep
        coroutine.resume(co)      --继续执行 sleep(50) 至结束
    end)
    self:report("profile coroutine+sleep workload", co_ok == true, co_err, "no exception")
    dump_profile(prof, "coroutine+sleep", 20)

    ------------------------------------------------------------------
    --5. 典型样例: pcall 抛错 1000 次(master 原有 index==3 样例)
    --   帧异常返回, 验证 profiler 对错误帧的处理
    ------------------------------------------------------------------
    local function assert_test(n)
        return assert(n > 100, "boom")   --必抛错(n 从 1 到 1000, 前 100 次触发), 帧异常返回
    end
    local function error_in_pcall(n)
        busy_work(20)
        assert_test(n)
    end
    local outer_pcall = function(n) return pcall(error_in_pcall, n) end
    local pc_ok, pc_err = pcall(function()
        prof.enable()
        for i = 1, 1000 do outer_pcall(i) end
    end)
    self:report("profile pcall workload", pc_ok == true, pc_err, "no exception")
    dump_profile(prof, "pcall", 20)

    ------------------------------------------------------------------
    --6. flame 落盘: SVG 文件生成且内容含 <svg
    ------------------------------------------------------------------
    prof.enable()
    for _ = 1, 20 do busy_work(100) end
    local flame_ret = prof.flame(self.svg_path, false)
    self:report("flame returns true", flame_ret == true, flame_ret, "true")
    self:report("flame svg created", stdfs.exists(self.svg_path) == true, stdfs.exists(self.svg_path), "true")
    if stdfs.exists(self.svg_path) then
        local f = io.open(self.svg_path, "r")
        local content = f and f:read(64) or ""
        if f then f:close() end
        self:report("flame svg content", content:find("<svg", 1, true) ~= nil, sformat("head={}", content:sub(1, 16)), "<svg ...")
    end
    prof.disable()
end

return ProfileTest
