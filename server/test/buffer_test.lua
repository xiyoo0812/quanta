--buffer_test.lua
local lbuffer       = require("lbuffer")
local lcrypt        = require("lcrypt")

local log_debug     = logger.debug
local lhex_encode   = lcrypt.hex_encode
local lencode       = lbuffer.encode
local ldecode       = lbuffer.decode
local lserialize    = lbuffer.serialize
local lunserialize  = lbuffer.unserialize

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

local ss = lserialize(t)
log_debug("serialize-> aaa: %s", ss)
local tt = lunserialize(ss)
for k, v in pairs(tt) do
    log_debug("unserialize k=%s, v=%s", k, v)
end

--encode
local a = 1
local b = 2
local c = 4
local es = lencode(a, b, c, 5)
log_debug("encode-> aa: %s, %d", lhex_encode(es), #es)
local da, db, dc, dd = ldecode(es)
log_debug("decode-> %s, %s, %s, %s", da, db, dc, dd)
