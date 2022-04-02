--protobuf_test.lua

local protobuf_mgr  = quanta.get("protobuf_mgr")

local log_debug     = logger.debug
local NCmdId        = ncmd_cs.NCmdId

local pb_data  = {
    serial = 80,
    time = 801
}

local pb_str = protobuf_mgr:encode(NCmdId.NID_HEARTBEAT_REQ, pb_data)
local data = protobuf_mgr:decode(NCmdId.NID_HEARTBEAT_RES, pb_str)

log_debug("serial:%d", data.serial)
log_debug("time:%d", data.time)

