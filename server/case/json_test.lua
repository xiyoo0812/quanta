--json_test.lua
local ljson = require("luacjson")
ljson.encode_sparse_array(true)

local new_guid      = guid.new
local json_encode   = ljson.encode
local json_decode   = ljson.decode

local test  = {
    tid = 3.1415926,
    player_id = new_guid()
}

print(test.tid)
print(test.player_id)

local a = json_encode(test)
print(a)

local b = json_decode(a)
print(type(b.tid), b.tid)
print(type(b.player_id), b.player_id)

os.exit()
