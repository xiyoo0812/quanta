-- http2_test.lua

local log_debug     = logger.debug

local version       = "h2"
local thread_mgr    = quanta.get("thread_mgr")
local http_client   = quanta.http_client(version)

thread_mgr:fork(function()
    local ok, status, res, headers = http_client:call_get("https://yuanbao.tencent.com/download")
    log_debug("tiobe1 : {}, {}, {}, {}", ok, status, res, headers)

    -- thread_mgr:sleep(3000)
    -- local ok1, status1, res1, headers2 = http_client:call_get("https://yuanbao.tencent.com/download")
    -- log_debug("tiobe2 : {}, {}, {}, {}", ok1, status1, res1, headers2)
end)