--proxy_mgr.lua
import("driver/http.lua")
local log_err       = logger.err

local http          = quanta.http
local event_mgr     = quanta.event_mgr

local ProxyMgr = singleton()

function ProxyMgr:__init()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_http_post")
    event_mgr:add_listener(self, "rpc_http_get")
end

function ProxyMgr:rpc_http_get(url, query, headers)
    local ok, status, res = http:call_get(url, query, headers)
    if not ok then
        log_err("ProxyMgr:rpc_http_get ok=%s, status=%s", ok, status)
        return 404
    end
    return status, res
end

function ProxyMgr:rpc_http_post(url, query, post_data, headers)
    local ok, status, res = http:call_post(url, query, post_data, headers)
    if not ok then
        log_err("ProxyMgr:rpc_http_post ok=%s, status=%s", ok, status)
        return 404
    end
    return status, res
end

quanta.proxy_mgr = ProxyMgr()

return ProxyMgr
