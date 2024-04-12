-- http_test.lua
import("network/http_client.lua")

local log_debug     = logger.debug
local thread_mgr    = quanta.get("thread_mgr")
local http_client   = quanta.get("http_client")

thread_mgr:fork(function()
    local ok, status, res, headers = http_client:call_get("https://www.163.com/")
    log_debug("node_status4 : {}, {}, {}, {}", ok, status, res, headers)
end)
