--bitset_test.lua

local log_debug = logger.debug

local bval = codec.bit32_new()
log_debug("bit32_new: {}", bval)
local fval = codec.bit32_flip(bval, 3)
log_debug("bit32_flip: {}-{}", bval, fval)
log_debug("bit32_get: {}-{}", codec.bit32_get(fval, 3), codec.bit32_get(fval, 2))

local bval2 = codec.bit32_new("010000101")
log_debug("bit32_new: {}", bval2)
local sval = codec.bit32_set(bval2, 4, true)
log_debug("bit32_set: {}-{}", bval2, sval)
local sval2 = codec.bit32_set(sval, 2, true)
log_debug("bit32_set: {}-{}", bval2, sval2)
log_debug("bit32_check 4: {}", codec.bit32_check(sval2, 4))
log_debug("bit32_check 5: {}", codec.bit32_check(sval2, 5))

