--json_test.lua
local ltimer    = require("ltimer")
local ljson     = require("lcjson")
local lcodec    = require("lcodec")

local log_debug     = logger.debug
local json_encode   = ljson.encode
local json_decode   = ljson.decode
local new_guid      = lcodec.guid_new
local encode_slice  = lcodec.encode_slice
local decode_slice  = lcodec.decode_slice
local ltime         = ltimer.time

local test  = {
    tid = 3.1415926,
    player_id = new_guid(),
    c = {[2]=1}
}


log_debug(test.tid)
log_debug(test.player_id)

local a = json_encode(test)
log_debug(a)

local b = json_decode(a)
for k, v in pairs(b.c) do
    log_debug("%s, %s, %s", type(k), k, v)
end

log_debug("%s", b.c)
log_debug("%s, %s", type(b.tid), b.tid)
log_debug("%s, %s", type(b.player_id), b.player_id)

local tt = { region = 123, group = 3324, id = 122143556, name = "nodename", host = "127.0.0.1", port = 3369 }
local x1 = json_encode(tt)
log_debug("tt1:%s", x1)
local x2 = encode_slice(tt)
local ts = decode_slice(x2)
log_debug("tt21:%s", json_encode(ts))

local tt1 = ltime()
for i = 1, 200000 do
    local x = json_encode(tt)
    json_decode(x)
end
local tt2 = ltime()
for i = 1, 200000 do
    local x = encode_slice(tt)
    decode_slice(x)
end
local tt3 = ltime()

log_debug("tt1:%s, tt2:%s", tt2 - tt1, tt3 - tt2)

