--protobuf_test.lua

local protobuf_mgr  = quanta.get("protobuf_mgr")

local log_debug     = logger.debug
local NCmdId        = ncmd_cs.NCmdId

local pb_data  = {
    serial = 1,
    time = 801000000
}
local pb_str1 = protobuf_mgr:encode("NID_HEARTBEAT_REQ", pb_data)
local data1 = protobuf_mgr:decode("NID_HEARTBEAT_REQ", pb_str1)
local pb_str2 = protobuf_mgr:encode(NCmdId.NID_HEARTBEAT_REQ, pb_data)
local data2 = protobuf_mgr:decode(NCmdId.NID_HEARTBEAT_REQ, pb_str2)
log_debug("name test1:{}", data1)
log_debug("name test2:{}", data2)

local ppb_data = {master=1001014162,elems={[107216333761938434]={proto_id=0}},part_sync=true}
local ppb_str = protobuf_mgr:encode_byname("ncmd_cs.building_building_ntf", ppb_data)
local pdata = protobuf_mgr:decode_byname("ncmd_cs.building_building_ntf", ppb_str)

log_debug("pb test:{}", #ppb_str)
log_debug("pb test:{}", pdata)
