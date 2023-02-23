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

log_debug("name test:%s", data1)
log_debug("id test:%s", data2)
