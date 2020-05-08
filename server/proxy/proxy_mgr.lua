--proxy_mgr.lua
local http = import("driver/http.lua")
local log_err       = logger.err

local event_mgr     = quanta.event_mgr

local LogMgr = singleton()

function LogMgr:__init()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_http_post")
    event_mgr:add_listener(self, "rpc_http_get")
end

function LogMgr:rpc_http_get(url, query, headers)
    local ok, status, res = http.call_get(url, query, headers)
    if not ok then
        log_err("HttpMgr:rpc_http_get ok=%s, status=%s", ok, status)
        return 404
    end

    return status, res
end

function LogMgr:rpc_http_post(url, query, post_data, headers)
    local ok, status, res = http.call_post(url, query, post_data, headers)
    if not ok then
        log_err("HttpMgr:rpc_http_post ok=%s, status=%s", ok, status)
        return 404
    end
    return status, res
end

quanta.proxy_mgr = LogMgr()

return LogMgr
