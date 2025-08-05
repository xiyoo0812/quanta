-- http2_test.lua
import("network/http2_client.lua")

local ltime         = timer.time
local log_debug     = logger.debug
local thread_mgr    = quanta.get("thread_mgr")
local http2_client  = quanta.get("http2_client")

thread_mgr:fork(function()
    local tk2 = ltime()
    local ok, status, res, headers = http2_client:call_get("https://yuanbao.tencent.com/download")
    log_debug("tiobe : {}, {}, {}, {}, {}", ltime() - tk2, ok, status, res, headers)
end)