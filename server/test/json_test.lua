--json_test.lua

local jencode       = json.encode
local jdecode       = json.decode
local jpretty       = json.pretty
local bencode       = bson.encode
local bdecode       = bson.decode
local log_debug     = logger.debug
local new_guid      = codec.guid_new
local lencode       = luakit.encode
local ldecode       = luakit.decode

local protobuf_mgr  = quanta.get("protobuf_mgr")

local test = {
    tid = 3.1415926,
    player_id = new_guid(),
    c = {[2]=1},
    d = {1, 2, 4, 5, 6},
    effect = {a=3, b=6}
}

local value = {
    error_code = 100005,
    user_id = 23024214324234,
    roles = {
        {role_id = 134234234, name = "asdasdas3", gender= 1, model = 231323},
        {role_id = 134234233, name = "asdasdas1", gender= 2, model = 231324},
        {role_id = 134234234, name = "asdasdas2", gender= 3, model = 231325},
    }
}

log_debug(test.tid)
log_debug(test.player_id)

local vv = {
    status = 0,
    timestamp = 0,
    proto_id = 40001,
    partners = {227942049067380831},
    detail = protobuf_mgr:encode_byname("ncmd_cs.login_account_login_res", value)
}

log_debug("{}, {}", #vv.detail, vv.detail)

local c = jpretty(vv)
log_debug("json_encode: {}", c)

local d = jdecode(c)
log_debug("json_decode: {}", d)

local dd = protobuf_mgr:decode_byname("ncmd_cs.login_account_login_res", d.detail)
log_debug("decode_byname: {}", dd)

local a = jencode(test, 1)
log_debug("json_encode: {}", a)

local b = jdecode(a, 1)
log_debug(type(b.tid), b.tid)
log_debug(type(b.player_id), b.player_id)
log_debug("json_decode: {}", b)

log_debug("{}", b.c)
log_debug("{}, {}", type(b.tid), b.tid)
log_debug("{}, {}", type(b.player_id), b.player_id)
for k, v in pairs(b.c) do
    log_debug("c {}, {}", type(k), k)
    log_debug("c {}, {}", type(v), v)
end

local x1 = jencode(test)
log_debug("tt1:{}", x1, #x1)

local aaa = lencode(test)
local bbb = ldecode(aaa)
log_debug("tt22:{}", bbb, #aaa)

local aaa1 = bencode(test)
local bbb1 = bdecode(aaa1)
log_debug("tt23:{}", bbb1, #aaa1)

