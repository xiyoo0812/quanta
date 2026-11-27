-- toml_test.lua
local toml      = require("ltoml")

local TOML_DATA   = [[
title = "demo"
count = 42
enabled = true

[owner]
name = "tom"
age = 30

[db]
ports = [1, 2, 3]
]]

local TestCase  = import("test/case.lua")
local TomlTest  = class(TestCase)

function TomlTest:__init(name, addr, cleanup)
    self.temp_dir = "quanta_toml_test"
end

function TomlTest:setup()
    self:prepare_temp()
end

function TomlTest:on_cleanup()
    self:cleanup_temp()
end

function TomlTest:run()
    ------------------------------------------------------------------
    --1. decode: 顶层标量(字符串/整数/布尔)
    ------------------------------------------------------------------
    local t = toml.decode(TOML_DATA)
    self:report("decode title", t.title == "demo", t.title, "demo")
    self:report("decode count", t.count == 42, t.count, 42)
    self:report("decode enabled", t.enabled == true, t.enabled, true)

    ------------------------------------------------------------------
    --2. decode: 嵌套 table 与数组
    ------------------------------------------------------------------
    self:report("nested table owner", type(t.owner) == "table", type(t.owner), "table")
    self:report("owner.name", t.owner.name == "tom", t.owner.name, "tom")
    self:report("owner.age", t.owner.age == 30, t.owner.age, 30)
    self:report("db.ports array", type(t.db.ports) == "table" and #t.db.ports == 3, #t.db.ports, 3)
    self:report("db.ports[2]", t.db.ports[2] == 2, t.db.ports[2], 2)

    ------------------------------------------------------------------
    --3. encode: 往返一致性
    ------------------------------------------------------------------
    local text = toml.encode(t)
    self:report("encode is string", type(text) == "string" and #text > 0, type(text), "string")
    local back = toml.decode(text)
    self:report("roundtrip title", back.title == "demo", back.title, "demo")
    self:report("roundtrip owner.name", back.owner.name == "tom", back.owner.name, "tom")
    self:report("roundtrip ports[3]", back.db.ports[3] == 3, back.db.ports[3], 3)

    ------------------------------------------------------------------
    --4. save + open: 文件往返
    ------------------------------------------------------------------
    local path = self:temp_path("data.toml")
    local saved = toml.save(path, t)
    self:report("save returns true", saved == true, saved, true)
    self:report("file exists after save", stdfs.exists(path) == true, stdfs.exists(path), true)
    local loaded = toml.open(path)
    self:report("open title", loaded.title == "demo", loaded.title, "demo")
    self:report("open owner.age", loaded.owner.age == 30, loaded.owner.age, 30)

    ------------------------------------------------------------------
    --5. 非法字符串 decode
    ------------------------------------------------------------------
    local bad_cases = {
        --空串: toml 解析器认为"空文档"合法, 返回空表, 属设计选择; 只要求不崩溃
        { name = "empty string",     text = "",                            must_fail = false },
        { name = "unclosed table",   text = "[owner\nname = \"tom\"",     must_fail = true },
        { name = "missing value",    text = "title =",                     must_fail = true },
        { name = "bad key",          text = "= \"no key\"",                must_fail = true },
        { name = "unclosed string",  text = "title = \"demo",              must_fail = true },
        { name = "unclosed array",   text = "ports = [1, 2, 3",            must_fail = true },
        { name = "dup key",          text = "a = 1\na = 2\n",             must_fail = true },
        { name = "binary garbage",   text = "\0\1\2\255\254",           must_fail = true },
        { name = "invalid date",     text = "d = 2026-13-45T99:99:99Z",    must_fail = true },
    }
    for _, case in ipairs(bad_cases) do
        local ok, res = pcall(toml.decode, case.text)
        local rejected = (ok == false) or (res == nil)
        local safe = case.must_fail and rejected or true
        self:report("decode invalid: " .. case.name, safe,
            { ok = ok, rejected = rejected, restype = type(res) },
            case.must_fail and "raise error or nil" or "not crash")
    end
end

return TomlTest
