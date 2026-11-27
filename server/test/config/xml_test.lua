-- xml_test.lua

local xml       = require("luaxml")

local XML_DATA    = [[
<root ver="1.0">
  <name>alice</name>
  <count>42</count>
  <score>3.5</score>
  <item id="a">first</item>
  <item id="b">second</item>
</root>
]]

local TestCase  = import("test/case.lua")
local XmlTest   = class(TestCase)

function XmlTest:__init(name, addr, cleanup)
    self.temp_dir = "quanta_xml_test"
end

function XmlTest:setup()
    self:prepare_temp()
end

function XmlTest:on_cleanup()
    self:cleanup_temp()
end

function XmlTest:run()
    ------------------------------------------------------------------
    --1. decode: 根节点与属性
    ------------------------------------------------------------------
    local t = xml.decode(XML_DATA)
    self:report("decode root exists", t.root ~= nil, t.root ~= nil, true)
    local r = t.root
    --属性值 "1.0" 含小数点, 按新规则保留为字符串(纯整数才会转 number)
    self:report("root.__attr.ver", r.__attr and r.__attr.ver == "1.0", r.__attr and r.__attr.ver, "1.0")

    ------------------------------------------------------------------
    --2. 叶子节点 __text, 自动转数字
    ------------------------------------------------------------------
    self:report("name.__text", r.name.__text == "alice", r.name.__text, "alice")
    self:report("count.__text number", r.count.__text == 42, r.count.__text, 42)
    --"3.5" 含小数点, 保留为字符串
    self:report("score.__text string", r.score.__text == "3.5", r.score.__text, "3.5")

    ------------------------------------------------------------------
    --3. 同名多节点 -> 数组, 各自属性
    ------------------------------------------------------------------
    self:report("item is array", type(r.item) == "table" and #r.item == 2, #r.item, 2)
    self:report("item[1].__attr.id", r.item[1].__attr.id == "a", r.item[1].__attr.id, "a")
    self:report("item[2].__text", r.item[2].__text == "second", r.item[2].__text, "second")

    ------------------------------------------------------------------
    --4. encode: 带版本号和编码
    ------------------------------------------------------------------
    local text = xml.encode(t, "1.0", "UTF-8")
    self:report("encode is string", type(text) == "string" and #text > 0, type(text), "string")
    self:report("encode has declaration", text:find("<?xml") ~= nil, text:sub(1, 5), "<?xml")
    self:report("encode has root", text:find("root") ~= nil, true, true)
    local back = xml.decode(text)
    self:report("roundtrip name", back.root.name.__text == "alice", back.root.name.__text, "alice")

    ------------------------------------------------------------------
    --5. save + open: 文件往返(version/encoding 是第 3/4 参数)
    ------------------------------------------------------------------
    local path = self:temp_path("data.xml")
    local fresh = xml.decode(XML_DATA)   --用干净的表, 避免 encode 可能的副作用
    local saved = xml.save(path, fresh, "1.0", "UTF-8")
    self:report("save returns true", saved == true, saved, true)
    self:report("file exists after save", stdfs.exists(path) == true, stdfs.exists(path), true)
    local loaded = xml.open(path)
    self:report("open returns table", type(loaded) == "table" and loaded.root ~= nil, type(loaded), "table")
    if type(loaded) == "table" and loaded.root then
        self:report("open count", loaded.root.count and loaded.root.count.__text == 42,
            loaded.root.count and loaded.root.count.__text, 42)
    end

    ------------------------------------------------------------------
    --6. 非法字符串 decode
    ------------------------------------------------------------------
    local bad_cases = {
        { name = "empty string",    text = "" },
        { name = "unclosed tag",    text = "<root><name>alice</root>" },
        { name = "no root",         text = "just text" },
        { name = "unclosed attr",   text = "<root ver=\"1.0></root>" },
        { name = "stray closing",   text = "</root>" },
        { name = "bad declaration", text = "<?xml <root/>" },
        { name = "binary garbage",  text = "\0\1\2\255\254" },
    }
    for _, case in ipairs(bad_cases) do
        local ok, res, err = pcall(xml.decode, case.text)
        --三种安全情形: pcall 抛错 / 返回 nil / 返回不含根节点的空表
        local safe
        if ok == false then
            safe = true
        elseif res == nil then
            safe = true
        else
            safe = (type(res) == "table") and (next(res) == nil)
        end
        self:report("decode invalid: " .. case.name, safe,
            { ok = ok, restype = type(res), err = err }, "error or nil or empty table")
    end
end

return XmlTest
