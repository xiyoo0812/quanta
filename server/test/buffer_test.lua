--buffer_test.lua
local lcrypt        = require("lcrypt")

local log_debug     = logger.debug
local log_dump      = logger.dump
local lhex_encode   = lcrypt.hex_encode

local encode        = quanta.encode
local decode        = quanta.decode
local serialize     = quanta.serialize
local unserialize   = quanta.unserialize
local encode_string = quanta.encode_string
local decode_string = quanta.decode_string

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
local slice = encode(e)
local bufs = slice.string()
local bufe = encode_string(e)
log_debug("encode-> bufe: %d, %s", #bufe, lhex_encode(bufe))
log_debug("encode-> bufs: %d, %s", #bufs, lhex_encode(bufs))

local datae = decode(slice)
log_debug("decode-> %s", datae)
local datas = decode_string(bufe)
log_debug("decode_string-> %s", datas)

local a = 1
local b = 2
local c = 4
local es = encode(a, b, c, 5)
local ess = es.string()
log_debug("encode-> aa: %d, %s", #ess, lhex_encode(ess))
local da, db, dc, dd = decode(es)
log_debug("decode-> %s, %s, %s, %s", da, db, dc, dd)

--dump
log_dump("dump-> a: %s", t)
