--protobuf_test.lua

local protobuf_mgr  = quanta.get("protobuf_mgr")

local log_debug     = logger.debug
local NCmdId        = ncmd_cs.NCmdId

--[[
local pb_data  = {
    serial = 1,
    time = 801000000
}
local pb_str1 = protobuf_mgr:encode("NID_HEARTBEAT_REQ", pb_data)
local data1 = protobuf_mgr:decode("NID_HEARTBEAT_REQ", pb_str1)
local pb_str2 = protobuf_mgr:encode(NCmdId.NID_HEARTBEAT_REQ, pb_data)
local data2 = protobuf_mgr:decode(NCmdId.NID_HEARTBEAT_REQ, pb_str2)
log_debug("name test:%s", data1)

]]

local pb_data = {master=1001014162,elems={[107216333761938434]={proto_id=0}},part_sync=true}
local pb_str1 = protobuf_mgr:encode_byname("ncmd_cs.building_building_ntf", pb_data)
local data1 = protobuf_mgr:decode_byname("ncmd_cs.building_building_ntf", pb_str1)

log_debug("name test:%s", #pb_str1)
log_debug("name test:%s", data1)
