--protobuf_test.lua
local pb = require("pb")

pb.loadfile("proto/ncmd_cs.pb")

local log_dump      = logger.dump
local pbdecode      = pb.decode
local pbencode      = pb.encode
local lpbdecode     = protobuf.decode
local lpbencode     = protobuf.encode

local intmin = {
    u32 = 0,
    u64 = 0,
    f32 = 0,
    f64 = 0,
    i32 = -2147483648,
    s32 = -2147483648,
    sf32 = -2147483648,
    i64 = -9223372036854775808,
    s64 = -9223372036854775808,
    sf64 = -9223372036854775808,
    d32 = 0,
    d64 = 0,
}

local intnor = {
    i32 = -60,
    s32 = -666,
    u32 = 98656,
    f32 = 9865688,
    sf32 = -6665,
    i64 = -554545,
    sf64 = 6568454,
    u64 = 98456445645,
    s64 = 645645,
    f64 = 88654465465,
    d32 = 3.141592,
    d64 = 3.1415926535,
}

local intmax = {
    i32 = 2147483647,
    s32 = 2147483647,
    u32 = 4294967295,
    f32 = 4294967295,
    sf32 = 2147483647,
    i64 = 9223372036854775807,
    sf64 = 9223372036854775807,
    s64 = 9223372036854775807,
    u64 = 0xFFFFFFFFFFFFFFFF,
    f64 = 0xFFFFFFFFFFFFFFFF,
    d32 = math.huge,
    d64 = 1.7976931348623157e308,
}

local min_str = pbencode("ncmd_cs.num_message", intmin)
log_dump("pb min encode: {}", #min_str)
local lmin_str = lpbencode("ncmd_cs.num_message", intmin)
log_dump("lpb min encode: {}", #lmin_str)

local mtdata = pbdecode("ncmd_cs.num_message", min_str)
local lmtdata = lpbdecode("ncmd_cs.num_message", lmin_str)
for k in pairs(intmin) do
    log_dump("pb min decode: key {}, value=> pb={} : lpb={}", k, mtdata[k], lmtdata[k])
end

local max_str = pbencode("ncmd_cs.num_message", intmax)
log_dump("pb max encode: {}", #max_str)
local lmax_str = lpbencode("ncmd_cs.num_message", intmax)
log_dump("lpb max encode: {}", #lmax_str)

local xtdata = pbdecode("ncmd_cs.num_message", max_str)
local lxtdata = lpbdecode("ncmd_cs.num_message", lmax_str)

for k in pairs(intmax) do
    log_dump("pb max decode: key {}, value=> pb={} : lpb={}", k, xtdata[k], lxtdata[k])
end

local nor_str = pbencode("ncmd_cs.num_message", intnor)
log_dump("pb nor encode: {}", #nor_str)
local lnor_str = lpbencode("ncmd_cs.num_message", intnor)
log_dump("lpb nor encode: {}", #lnor_str)

local ntdata = pbdecode("ncmd_cs.num_message", lnor_str)
local lntdata = lpbdecode("ncmd_cs.num_message", nor_str)

for k in pairs(intnor) do
    log_dump("pb nor decode: key {}, value=> pb={} : lpb={}", k, ntdata[k], lntdata[k])
end

local tpb_data = {
    id=1001014162,
    child = {id=1, name="hot", values = {one="xiluo", two="wergins"} },
    childs = {
        {id=2, name="laker", values = {one="doncici", two="james"} },
        {id=3, name="gsa", values = {one="curry", two="green"} },
    },
    kvs = {
        king = {id=4, name="king", values = {one="drozan", two="foxs"} },
        capper = {id=5, name="capper", values = {one="harden", two="lenarde"} },
    },
    custom={role_id="107216333761938434",name="aaa", gender = "2", model = "3"},
    custom2={1, 2, 3, 888, 666},
    str= "oneof str",
    num= 10,
}

local tpb_str = pbencode("ncmd_cs.test_message", tpb_data)
log_dump("pb encode: {}", #tpb_str)
local tdata = pbdecode("ncmd_cs.test_message", tpb_str)
log_dump("pb decode:{}", tdata)
