-- codec_test.lua
local sformat      = string.format
local hex          = codec.hex_encode
local hash_code    = codec.hash_code

local TestCase     = import("test/case.lua")
local CodecTest    = class(TestCase)

function CodecTest:run()
    ------------------------------------------------------------------
    --1. hash: 数字/字符串, 带取模
    ------------------------------------------------------------------
    local hn1 = hash_code(12345)
    local hn2 = hash_code(123346456545464, 1000)
    self:report("hash number", type(hn1) == "number", hn1, "number")
    self:report("hash number mod", type(hn2) == "number" and hn2 >= 0 and hn2 < 1000, hn2, "[0,1000)")
    local hs2 = hash_code("a0b0c0d0a0b0c0d0", 1000)
    self:report("hash string mod", hs2 >= 0 and hs2 < 1000, hs2, "[0,1000)")

    ------------------------------------------------------------------
    --2. guid: 生成/转换/编解码/来源解析
    ------------------------------------------------------------------
    local guid = codec.guid_new(5, 512)
    local sguid = codec.guid_tostring(guid)
    self:report("guid string roundtrip", codec.string_toguid(sguid) == guid, codec.string_toguid(sguid), guid)
    self:report("guid tostring/hex", type(sguid) == "string" and type(codec.guid_tohex(guid)) == "string", sguid, "string")
    self:report("guid group", codec.guid_group(codec.guid_string(5, 512)) == 5, true, 5)
    self:report("guid index", codec.guid_index(guid) == 512, codec.guid_index(guid), 512)
    local eguid = codec.guid_encode(9223372036854775807)
    self:report("guid encode/decode", codec.guid_decode(eguid) == 9223372036854775807,
        codec.guid_decode(eguid), 9223372036854775807)
    local group, index = codec.guid_source(guid)
    self:report("guid source", group == 5 and index == 512, sformat("{},{}", group, index), "5,512")

    ------------------------------------------------------------------
    --3. serialize / luakit encode / hex
    ------------------------------------------------------------------
    local t = { [3.63] = 1, 2, 3, 4, a = 2, b = { s = 3, d = "4" }, e = true }
    local tt = string.unserialize(string.serialize(t))
    self:report("serialize/unserialize", type(tt) == "table" and tt.a == 2 and tt.b.d == "4", tt and tt.a, 2)
    local bufe = luakit.encode({ a = 1, c = { ab = 2 } })
    local datae = luakit.decode(bufe, #bufe)
    self:report("luakit encode/decode", type(datae) == "table" and datae.a == 1 and datae.c.ab == 2,
        datae and datae.a, 1)
    self:report("hex_encode", hex("AB") == "4142", hex("AB"), "4142")

    ------------------------------------------------------------------
    --4. bitset(合并自 bitset_test): 注意方法用点号调用, 索引 1-based
    --   check(pos) 语义是"前 pos 位全为 1"; tostring(true) 显示完整位串
    ------------------------------------------------------------------
    local bs = codec.bitset()
    self:report("bitset init", bs.tostring(true) == "0000000000000000", bs.tostring(true), "0000000000000000")
    self:report("bitset set", bs.set(1, true) == true and bs.get(1) == true, bs.get(1), true)
    bs.set(2, true)
    self:report("bitset check prefix", bs.check(2) == true and bs.check(3) == false, true, true)
    bs.flip(3)
    self:report("bitset flip", bs.check(3) == true, bs.check(3), true)
    bs.load("101")
    self:report("bitset load", bs.get(1) == true and bs.get(2) == false and bs.get(3) == true, true, true)
    local bval = codec.bitset()
    bval.loadbin(bs.binary())
    self:report("bitset binary roundtrip", bval.get(1) == true and bval.get(3) == true, true, true)
    local hval = codec.bitset()
    hval.loadhex(bs.hex())
    self:report("bitset hex roundtrip", hval.get(1) == true and hval.get(3) == true, true, true)
    bval.reset(1)
    self:report("bitset reset", bval.get(1) == false, bval.get(1), false)
end

return CodecTest
