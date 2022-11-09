--codec_test.lua
local luabus        = require("luabus")
local lcrypt        = require("lcrypt")
local lcodec        = require("lcodec")

local log_debug     = logger.debug
local log_dump      = logger.dump
local lhex_encode   = lcrypt.hex_encode

local encode        = lcodec.encode
local decode        = lcodec.decode
local encode_slice  = lcodec.encode_slice
local decode_slice  = lcodec.decode_slice
local serialize     = lcodec.serialize
local unserialize   = lcodec.unserialize
local hash_code     = lcodec.hash_code
local fnv_32a       = lcodec.fnv_1a_32
local fnv_32        = lcodec.fnv_1_32
local jumphash      = lcodec.jumphash

--ketama
lcodec.ketama_insert("test1", quanta.id)
lcodec.ketama_insert("test2", quanta.id + 1)
lcodec.ketama_insert("test3", quanta.id + 2)
lcodec.ketama_insert("test4", quanta.id + 3)
lcodec.ketama_insert("test5", quanta.id + 4)
lcodec.ketama_insert("test6", quanta.id + 5)
lcodec.ketama_insert("test7", quanta.id + 6)
lcodec.ketama_insert("test8", quanta.id + 7)
lcodec.ketama_insert("test9", quanta.id + 8)
lcodec.ketama_insert("test10", quanta.id + 9)

local map = lcodec.ketama_map()
local qmap = qtable.mapsort(map)
for _, value in pairs(qmap) do
    log_debug("ketama_map: %s, %s", value[1], value[2])
end
log_debug("ketama_insert number: %s", qtable.size(map))

--hash
----------------------------------------------------------------
local hash_n1 = hash_code(12345)
local hash_n2 = hash_code(123346456545464, 1000)
log_debug("hash_code number: %s, %s", hash_n1, hash_n2)

local hash_s1 = hash_code("12345")
local hash_s2 = hash_code("a0b0c0d0a0b0c0d0", 1000)
log_debug("hash_code string: %s, %s", hash_s1, hash_s2)

local fnv_s1 = fnv_32("")
local fnv_s2 = fnv_32("12345", fnv_s1)
local fnv_s3 = fnv_32("12345", fnv_s2)
log_debug("fnv_32 string: %s, %s, %s", fnv_s1, fnv_s2, fnv_s3)

local fnv_as1 = fnv_32a("12345")
local fnv_as2 = fnv_32a("12345", fnv_as1)
local fnv_as3 = fnv_32a("12345", fnv_as2)
log_debug("fnv_32a string: %s, %s, %s", fnv_as1, fnv_as2, fnv_as3)
--fnv_32 string: 2930711257, 991336454, 3269464323
--fnv_32a string: 3601286043, 177295730, 3384461241

local jmpv = jumphash("", 3)
log_debug("jumphash value: %s", jmpv)

--guid
----------------------------------------------------------------
local guid = lcodec.guid_new(5, 512)
local sguid = lcodec.guid_tostring(guid)
log_debug("newguid-> guid: %s, n2s: %s", guid, sguid)
local nguid = lcodec.guid_number(sguid)
local s2guid = lcodec.guid_tostring(nguid)
log_debug("convert-> guid: %s, n2s: %s", nguid, s2guid)
local eguid = lcodec.guid_encode(9223372036854775807)
local eguid1 = lcodec.guid_encode(0x7fffffffffffffff)
log_debug("encode-> eguid: %s", eguid)
log_debug("encode-> eguid: %s", eguid1)
local dguid = lcodec.guid_decode(eguid)
local dguid1 = lcodec.guid_decode(eguid1)
log_debug("encode-> dguid: %s", dguid)
log_debug("encode-> dguid: %s", dguid1)
local nsguid = lcodec.guid_string(5, 512)
log_debug("newguid: %s", nsguid)
local group = lcodec.guid_group(nsguid)
local index = lcodec.guid_index(guid)
local time = lcodec.guid_time(guid)
log_debug("ssource-> group: %s, index: %s, time:%s", group, index, time)
local group2, index2, time2 = lcodec.guid_source(guid)
log_debug("nsource-> group: %s, index: %s, time:%s", group2, index2, time2)

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
log_debug("serialize-> aaa: %s", ss)

local tt = unserialize(ss)
for k, v in pairs(tt) do
    log_debug("unserialize k=%s, v=%s", k, v)
end

--encode
local e = {a = 1, c = {ab = 2}}
local bufe = encode(e)
local slice = encode_slice(e)
local bufs = slice.string()
log_debug("encode-> bufe: %d, %s", #bufe, lhex_encode(bufe))
log_debug("encode-> bufs: %d, %s", #bufs, lhex_encode(bufs))

local datas = decode_slice(slice)
log_debug("decode-> %s", datas)
local datae = decode(bufe, #bufe)
log_debug("decode-> %s", datae)

local a = 1
local b = 2
local c = 4
local es = encode_slice(a, b, c, 5)
local ess = es.string()
log_debug("encode-> aa: %d, %s", #ess, lhex_encode(ess))
local da, db, dc, dd = decode_slice(es)
log_debug("decode-> %s, %s, %s, %s", da, db, dc, dd)


local ip = luabus.dns("mtae-global-test-outer-zone-a-2-89e65514de3445cc.elb.us-east-1.amazonaws.com")
log_debug("luabus dns-> %s", ip)

--dump
log_dump("dump-> a: %s", t)
