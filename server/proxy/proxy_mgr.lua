--proxy_mgr.lua
import("kernel/network/http_client.lua")
local log_err       = logger.err

local event_mgr     = quanta.get("event_mgr")
local http_client   = quanta.get("http_client")

local ProxyMgr = singleton()

function ProxyMgr:__init()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_http_post")
    event_mgr:add_listener(self, "rpc_http_get")
end

function ProxyMgr:rpc_http_get(url, querys, headers)
    local ok, status, res = http_client:call_get(url, querys, headers)
    if not ok then
        log_err("ProxyMgr:rpc_http_get ok=%s, status=%s", ok, status)
        return 404
    end
    return status, res
end

function ProxyMgr:rpc_http_post(url, post_data, headers, querys)
    local ok, status, res = http_client:call_post(url, post_data, headers, querys)
    if not ok then
        log_err("ProxyMgr:rpc_http_post ok=%s, status=%s", ok, status)
        return 404
    end
    return status, res
end

function ProxyMgr:rpc_http_put(url, put_data, headers, querys)
    local ok, status, res = http_client:call_put(url, put_data, headers, querys)
    if not ok then
        log_err("ProxyMgr:rpc_http_put ok=%s, status=%s", ok, status)
        return 404
    end
    return status, res
end

function ProxyMgr:rpc_http_del(url, querys, headers)
    local ok, status, res = http_client:call_del(url, querys, headers)
    if not ok then
        log_err("ProxyMgr:rpc_http_del ok=%s, status=%s", ok, status)
        return 404
    end
    return status, res
end

quanta.proxy_mgr = ProxyMgr()

return ProxyMgr
