--bitset_test.lua

local log_debug = logger.debug

local val = codec.bitset()
log_debug("new: {}", val.tostring(true))

val.flip(3)
log_debug("flip: {}", val.tostring(true))
log_debug("get: {}-{}", val.get(3), val.get(2))

val.load("010000101")
log_debug("load: {}", val.tostring())

val.set(4, true)
val.set(2, true)
log_debug("set: {}", val.tostring())
log_debug("check 4-5: {},{}", val.check(4), val.check(5))

local bin = val.binary()
local bval = codec.bitset()
bval.loadbin(bin)
log_debug("loadbin: {}", bval.tostring())
bval.reset(2)
log_debug("reset: {}", bval.tostring())

local hex = val.hex()
log_debug("hex: {}", hex)
local hval = codec.bitset()
hval.loadhex(hex)
log_debug("loadhex: {}", hval.tostring(0))

