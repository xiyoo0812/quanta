--buffer_test.lua
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

--dump
log_dump("dump-> a: %s", t)
