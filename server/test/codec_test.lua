--codec_test.lua

local log_debug     = logger.debug
local log_dump      = logger.dump
local lhex_encode   = ssl.hex_encode

local hash_code     = codec.hash_code
local encode        = luakit.encode
local decode        = luakit.decode
local serialize     = luakit.serialize
local unserialize   = luakit.unserialize

quanta.profile()

--hash
----------------------------------------------------------------
local hash_n1 = hash_code(12345)
local hash_n2 = hash_code(123346456545464, 1000)
log_debug("hash_code number: {}, {}", hash_n1, hash_n2)

local hash_s1 = hash_code("12345")
local hash_s2 = hash_code("a0b0c0d0a0b0c0d0", 1000)
log_debug("hash_code string: {}, {}", hash_s1, hash_s2)

--guid
----------------------------------------------------------------
local guid = codec.guid_new(5, 512)
local sguid = codec.guid_tostring(guid)
log_debug("newguid-> guid: {}, n2s: {}", guid, sguid)
local nguid = codec.string_toguid(sguid)
local s2guid = codec.guid_tostring(nguid)
local h2guid = codec.guid_tohex(nguid)
log_debug("convert-> guid: {}, n2s: {}, n2s:{}", nguid, s2guid, h2guid)
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

local t1 = timer.clock_ms()
local ip = luabus.dns("www.google.com")
log_debug("luabus dns-> {}", ip)
log_debug("luabus dns-> {}", timer.clock_ms() - t1)

local host = luabus.host()
log_debug("luabus host-> {}", host)

--dump
log_dump("dump-> a: {}", t)

quanta.perfdump(50)
