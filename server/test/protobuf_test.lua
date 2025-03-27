--protobuf_test.lua

local protobuf_mgr  = quanta.get("protobuf_mgr")

local log_dump      = logger.dump
local pbdecode      = protobuf.decode
local pbencode      = protobuf.encode
local NCmdId        = ncmd_cs.NCmdId

local pb_data  = {
    serial = 1,
    time = 801000000
}
local pb_str1 = protobuf_mgr:encode("NID_HEARTBEAT_REQ", pb_data)
local data1 = protobuf_mgr:decode("NID_HEARTBEAT_REQ", pb_str1)
local pb_str2 = protobuf_mgr:encode(NCmdId.NID_HEARTBEAT_REQ, pb_data)
local data2 = protobuf_mgr:decode(NCmdId.NID_HEARTBEAT_REQ, pb_str2)
log_dump("name test1:{}", data1)
log_dump("name test2:{}", data2)

local ppb_data = {error_code=1001014162,role={role_id=107216333761938434,name="aaa", gender = 2, model = 3}}
local ppb_str = protobuf_mgr:encode_byname("ncmd_cs.login_role_create_res", ppb_data)
local pdata = protobuf_mgr:decode_byname("ncmd_cs.login_role_create_res", ppb_str)

log_dump("pb test:{}", #ppb_str)
log_dump("pb test:{}", pdata)


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

