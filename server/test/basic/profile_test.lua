-- profile_test.lua
-- 测试性能剖析模块。核心开关是 QUANTA_PROFILE:
--   * 未启用: quanta.profile/flamedump/perfdump 等均为 no-op, flamedump 返回 false;
--     此时断言"函数存在且可安全调用、flamedump 返回 false"。
--   * 已启用: require("lprofile") 注入全局 profile 表, 可开启/关闭采集,
--     执行一段负载后 dump 返回统计数据数组, flame 写 SVG 文件。
-- 覆盖: 接口存在性、enable/disable、watch/ignore、dump 数据结构、flame 落盘、profile.hook。
local TestCase   = import("test/case.lua")

local sformat    = string.format

local ProfileTest = class(TestCase)

local SVG_PATH   = stdfs.append(stdfs.temp_dir(), "quanta_profile_test.svg")

function ProfileTest:teardown()
    if self.enabled and _G.profile then
        pcall(function() _G.profile.disable() end)
    end
    if stdfs.exists(SVG_PATH) then
        stdfs.remove(SVG_PATH)
    end
end

--执行一段可被采样的工作
local function busy_work(n)
    local s = 0
    for i = 1, n do s = s + i end
    local t = {}
    for i = 1, 100 do t[i] = tostring(s + i) end
    return s
end

function ProfileTest:run()
    ------------------------------------------------------------------
    --1. quanta 封装的接口均存在
    ------------------------------------------------------------------
    local api = { "profile", "perfwatch", "perfignore", "flamedump", "perfdump" }
    local all_exist = true
    for _, name in ipairs(api) do
        if type(quanta[name]) ~= "function" then all_exist = false end
    end
    self:report("quanta profile api exists", all_exist, quanta.profile and "ok" or "missing", "all functions")

    ------------------------------------------------------------------
    --2. 检测开关状态
    ------------------------------------------------------------------
    local enabled = quanta.getenv("QUANTA_PROFILE") and true or false
    self.enabled = enabled
    self:report("QUANTA_PROFILE state readable", type(enabled) == "boolean", tostring(enabled), "boolean")

    if not enabled then
        ------------------------------------------------------------------
        --未启用: 全部为 no-op, 断言安全调用 + flamedump 返回 false
        ------------------------------------------------------------------
        local ok, err = pcall(function()
            quanta.profile()
            quanta.perfwatch("some_file.lua")
            quanta.perfignore("some_file.lua")
            quanta.perfdump(10)
        end)
        self:report("profile api no-op safe", ok == true, err, "no exception")
        local flame_ret = quanta.flamedump(SVG_PATH, false)
        self:report("flamedump disabled returns false", flame_ret == false, flame_ret, "false")
        self:report("flamedump wrote nothing", stdfs.exists(SVG_PATH) == false, stdfs.exists(SVG_PATH), "false")
        return
    end

    ------------------------------------------------------------------
    --3. 已启用: 底层 profile 表接口齐全
    ------------------------------------------------------------------
    self:report("profile lib loaded", type(_G.profile) == "table", type(_G.profile), "table")
    if type(_G.profile) ~= "table" then return end
    local prof = _G.profile
    local prof_api = { "enable", "disable", "hook", "watch", "dump", "flame", "ignore", "ignore_file", "ignore_func" }
    local prof_ok = true
    for _, name in ipairs(prof_api) do
        if type(prof[name]) ~= "function" then prof_ok = false end
    end
    self:report("profile lib api exists", prof_ok, prof_ok and "all" or "missing", "all functions")

    ------------------------------------------------------------------
    --4. enable + 采集负载 + perfdump(dump 返回统计数据)
    ------------------------------------------------------------------
    local eok, eerr = pcall(function()
        prof.enable()
        for _ = 1, 50 do busy_work(200) end
    end)
    self:report("profile enable + workload", eok == true, eerr, "no exception")
    local dump_ok, dump_res = pcall(function() return prof.dump(20) end)
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
    --5. watch / ignore 配置接口可调用
    ------------------------------------------------------------------
    local wok, werr = pcall(function()
        prof.watch("busy_work")
        prof.ignore_func("busy_work")
        prof.ignore_file("some_file.lua")
    end)
    self:report("profile watch/ignore callable", wok == true, werr, "no exception")

    ------------------------------------------------------------------
    --6. flame 落盘: SVG 文件生成且内容含 <svg
    ------------------------------------------------------------------
    prof.enable()
    for _ = 1, 20 do busy_work(100) end
    local flame_ret = quanta.flamedump(SVG_PATH, false)
    self:report("flamedump returns true", flame_ret == true, flame_ret, "true")
    self:report("flame svg created", stdfs.exists(SVG_PATH) == true, stdfs.exists(SVG_PATH), "true")
    if stdfs.exists(SVG_PATH) then
        local f = io.open(SVG_PATH, "r")
        local content = f and f:read(64) or ""
        if f then f:close() end
        self:report("flame svg content", content:find("<svg", 1, true) ~= nil, sformat("head={}", content:sub(1, 16)), "<svg ...")
    end
    prof.disable()
end

return ProfileTest
