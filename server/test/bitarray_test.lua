--bitarray_test.lua

local log_debug = logger.debug

local array = codec.bitarray(32)
log_debug("array1: %s", array.to_string())
array.fill(1)
log_debug("array11: %s", array.to_string())
array.flip(1)
log_debug("array12: %s", array.to_string())
array.flip_bit(3)
log_debug("array13: %s-%s", array.to_string(), array.get_bit(3))
array.from_uint32(65535)
log_debug("array2: %s-%s", array.to_string(), array.to_uint32())
array.rshift(1)
log_debug("array3: %s-%s", array.to_string(), array.to_uint32())
array.lshift(1)
log_debug("array4: %s-%s", array.to_string(), array.to_uint32())
array.set_bit(32, 1)
local a2 = array.clone()
log_debug("array5: %s", a2.to_string())
local a3 = a2.slice(1, 16)
log_debug("array51: %s", a3.to_string())
local a4 = a2.slice(17)
log_debug("array52: %s", a4.to_string())
a4.concat(a3)
log_debug("array6: %s", a4.to_string())
a4.reverse()
log_debug("array7: %s", a4.to_string())
log_debug("array8: %s-%s", a4.equal(a2), a3.equal(a2))
