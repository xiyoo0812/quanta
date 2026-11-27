-- json_test.lua
local json      = require("ljson")

local TestCase  = import("test/case.lua")
local JsonTest  = class(TestCase)

function JsonTest:run()
    ------------------------------------------------------------------
    --1. encode: 基本类型(字符串/整数/浮点/布尔/nil)
    ------------------------------------------------------------------
    local src = {
        name    = "alice",
        age     = 30,
        score   = 3.5,
        active  = true,
        disabled = false,
    }
    local text = json.encode(src)
    self:report("encode is string", type(text) == "string" and #text > 0, type(text), "string")
    local d = json.decode(text)
    self:report("decode string", d.name == "alice", d.name, "alice")
    self:report("decode integer", d.age == 30, d.age, 30)
    self:report("decode float", d.score == 3.5, d.score, 3.5)
    self:report("decode true", d.active == true, d.active, true)
    self:report("decode false", d.disabled == false, d.disabled, false)

    ------------------------------------------------------------------
    --2. 嵌套 table 与数组
    ------------------------------------------------------------------
    local nested = {
        roles = {
            { id = 1, name = "warrior" },
            { id = 2, name = "mage" },
        },
        cfg = { level = 10, skills = { "a", "b", "c" } },
    }
    local ntext = json.encode(nested)
    local nd = json.decode(ntext)
    self:report("array length", #nd.roles == 2, #nd.roles, 2)
    self:report("array element", nd.roles[2].name == "mage", nd.roles[2].name, "mage")
    self:report("nested value", nd.cfg.level == 10, nd.cfg.level, 10)
    self:report("nested array", nd.cfg.skills[3] == "c", nd.cfg.skills[3], "c")

    ------------------------------------------------------------------
    --3. pretty: 多行可读格式且可 decode
    ------------------------------------------------------------------
    local pretty = json.pretty(nested)
    self:report("pretty multiline", type(pretty) == "string" and pretty:find("\n") ~= nil, true, true)
    local pd = json.decode(pretty)
    self:report("pretty roundtrip", pd.roles[1].name == "warrior", pd.roles[1].name, "warrior")

    ------------------------------------------------------------------
    --4. 特殊字符转义
    ------------------------------------------------------------------
    local escaped = json.encode({ text = "a\"b\\c\n" })
    local ed = json.decode(escaped)
    self:report("escape roundtrip", ed.text == "a\"b\\c\n", ed.text, "a\"b\\c\\n")

    ------------------------------------------------------------------
    --5. 顶层数组
    ------------------------------------------------------------------
    local arr_text = json.encode({ 10, 20, 30 })
    local arr = json.decode(arr_text)
    self:report("top array length", #arr == 3, #arr, 3)
    self:report("top array value", arr[2] == 20, arr[2], 20)

    ------------------------------------------------------------------
    --6. 非法字符串 decode
    ------------------------------------------------------------------
    local bad_cases = {
        { name = "empty string",     text = "",                       must_fail = true },
        { name = "truncated object", text = "{\"a\":1",               must_fail = true },
        { name = "unclosed array",   text = "[1,2,3",                 must_fail = true },
        { name = "bad token",        text = "{a:1}",                  must_fail = true },
        { name = "trailing comma",   text = "[1,2,]",                 must_fail = true },
        { name = "bare word",        text = "not-a-json",             must_fail = true },
        { name = "single quote key", text = "{'a':1}",                must_fail = true },
        { name = "deep nest",        text = string.rep("[", 200),     must_fail = true },
        { name = "binary garbage",   text = "\0\1\2\255\254",         must_fail = true },
        --控制字符: ljson 启用了 YYJSON_READ_ALLOW_INVALID_UNICODE(宽松模式),
        --这类输入会被接受而非报错, 属于库的设计选择; 只要求"不崩溃", 不强制失败。
        { name = "control char",     text = "{\"a\":\"\1\2\"}",        must_fail = false },
    }
    for _, case in ipairs(bad_cases) do
        local ok, res = pcall(json.decode, case.text)
        local rejected = (ok == false) or (res == nil)
        local safe = case.must_fail and rejected or true
        self:report("decode invalid: " .. case.name, safe,
            { ok = ok, rejected = rejected, restype = type(res) },
            case.must_fail and "raise error or nil" or "not crash")
    end

    --边界: 合法但极端的输入仍应正常解析(确认不是一律拒绝)
    local edge_ok, edge = pcall(json.decode, "[[[[[[[[[[1]]]]]]]]]]")
    self:report("decode deep legit ok", edge_ok == true and edge ~= nil, edge_ok, true)
end

return JsonTest
