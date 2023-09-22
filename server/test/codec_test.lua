--codec_test.lua

local log_debug     = logger.debug
local log_dump      = logger.dump
local lhex_encode   = crypt.hex_encode

local crc8          = codec.crc8
local hash_code     = codec.hash_code
local fnv_32a       = codec.fnv_1a_32
local fnv_32        = codec.fnv_1_32
local jumphash      = codec.jumphash
local encode        = luakit.encode
local decode        = luakit.decode
local serialize     = luakit.serialize
local unserialize   = luakit.unserialize

--ketama
--[[
codec.ketama_insert("test1", quanta.id)
codec.ketama_insert("test2", quanta.id + 1)
codec.ketama_insert("test3", quanta.id + 2)
codec.ketama_insert("test4", quanta.id + 3)
codec.ketama_insert("test5", quanta.id + 4)
codec.ketama_insert("test6", quanta.id + 5)
codec.ketama_insert("test7", quanta.id + 6)
codec.ketama_insert("test8", quanta.id + 7)
codec.ketama_insert("test9", quanta.id + 8)
codec.ketama_insert("test10", quanta.id + 9)

local map = codec.ketama_map()
local qmap = qtable.mapsort(map)
for _, value in pairs(qmap) do
    log_debug("ketama_map: {}, {}", value[1], value[2])
end
log_debug("ketama_insert number: {}", qtable.size(map))
]]

--hash
----------------------------------------------------------------
local hash_n1 = hash_code(12345)
local hash_n2 = hash_code(123346456545464, 1000)
log_debug("hash_code number: {}, {}", hash_n1, hash_n2)

local hash_s1 = hash_code("12345")
local hash_s2 = hash_code("a0b0c0d0a0b0c0d0", 1000)
log_debug("hash_code string: {}, {}", hash_s1, hash_s2)

local fnv_s1 = fnv_32("")
local fnv_s2 = fnv_32("12345", fnv_s1)
local fnv_s3 = fnv_32("12345", fnv_s2)
log_debug("fnv_32 string: {}, {}, {}", fnv_s1, fnv_s2, fnv_s3)

local fnv_as1 = fnv_32a("12345")
local fnv_as2 = fnv_32a("12345", fnv_as1)
local fnv_as3 = fnv_32a("12345", fnv_as2)
log_debug("fnv_32a string: {}, {}, {}", fnv_as1, fnv_as2, fnv_as3)
--fnv_32 string: 2930711257, 991336454, 3269464323
--fnv_32a string: 3601286043, 177295730, 3384461241

local jmpv = jumphash("", 3)
log_debug("jumphash value: {}", jmpv)

--guid
----------------------------------------------------------------
local guid = codec.guid_new(5, 512)
local sguid = codec.guid_tostring(guid)
log_debug("newguid-> guid: {}, n2s: {}", guid, sguid)
local nguid = codec.guid_number(sguid)
local s2guid = codec.guid_tostring(nguid)
log_debug("convert-> guid: {}, n2s: {}", nguid, s2guid)
local eguid = codec.guid_encode(9223372036854775807)
local eguid1 = codec.guid_encode(0x7fffffffffffffff)
log_debug("encode-> eguid: {}", eguid)
log_debug("encode-> eguid: {}", eguid1)
local dguid = codec.guid_decode(eguid)
local dguid1 = codec.guid_decode(eguid1)
log_debug("encode-> dguid: {}", dguid)
log_debug("encode-> dguid: {}", dguid1)
local nsguid = codec.guid_string(5, 512)
log_debug("newguid: {}", nsguid)
local group = codec.guid_group(nsguid)
local index = codec.guid_index(guid)
local time = codec.guid_time(guid)
log_debug("ssource-> group: {}, index: {}, time:{}", group, index, time)
local group2, index2, time2 = codec.guid_source(guid)
log_debug("nsource-> group: {}, index: {}, time:{}", group2, index2, time2)

log_debug("crc8: {}", crc8("123214345345345"))
log_debug("crc8: {}", crc8("dfsdfsdfsdfgsdg"))
log_debug("crc8: {}", crc8("2213weerwbdfgd"))
log_debug("crc8: {}", crc8("++dsfsdf++gbdfgdfg"))

--serialize
----------------------------------------------------------------
local m = {f = 3}
local t = {
    [3.63] = 1, 2, 3, 4,
    a = 2,
    b = {
        s = 3, d = "4"
    },
    e = true,
    g = m,
}
local ss = serialize(t)
log_debug("serialize-> aaa: {}", ss)

local tt = unserialize(ss)
for k, v in pairs(tt) do
    log_debug("unserialize k={}, v={}", k, v)
end

--encode
local e = {a = 1, c = {ab = 2}}
local bufe = encode(e)
log_debug("encode-> bufe: {}, {}", #bufe, lhex_encode(bufe))

local datae = decode(bufe, #bufe)
log_debug("decode-> {}", datae)

local ip = luabus.dns("mtae-global-test-outer-zone-a-2-89e65514de3445cc.elb.us-east-1.amazonaws.com")
log_debug("luabus dns-> {}", ip)

--dump
log_dump("dump-> a: {}", t)
