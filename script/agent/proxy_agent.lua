--proxy_agent.lua
local sformat       = string.format
local tunpack       = table.unpack
local send_worker   = quanta.send_worker
local call_worker   = quanta.call_worker

local WTITLE        = quanta.worker_title

local event_mgr     = quanta.get("event_mgr")
local scheduler     = quanta.load("scheduler")

local ProxyAgent    = singleton()
local prop = property(ProxyAgent)
prop:reader("ignore_statistics", {})

function ProxyAgent:__init()
    if scheduler then
        --启动代理线程
        scheduler:startup("proxy", "worker.proxy")
    end
    --添加忽略的rpc统计事件
    self:ignore_statis("rpc_heartbeat")

    local wlvl = environ.number("QUANTA_WEBHOOK_LVL")
    if wlvl then
        --添加webhook功能
        logger.add_monitor(self, wlvl)
    end
end

--dispatch_log
function ProxyAgent:dispatch_log(content, lvl_name)
    self:fire_webhook(content, lvl_name)
end

--webhook
function ProxyAgent:fire_webhook(content, lvl_name)
    local title = sformat("%s | %s", quanta.service_name, lvl_name)
    self:send("rpc_fire_webhook", title, content)
end

--http_get
function ProxyAgent:http_get(url, querys, headers)
    return self:call("rpc_http_get", url, querys, headers)
end

--http_post
function ProxyAgent:http_post(url, post_data, headers, querys)
    return self:call("rpc_http_post", url, post_data, headers, querys)
end

--http_put
function ProxyAgent:http_put(url, put_data, headers, querys)
    return self:call("rpc_http_put", url, put_data, headers, querys)
end

--http_del
function ProxyAgent:http_del(url, querys, headers)
    return self:call("rpc_http_del", url, querys, headers)
end

function ProxyAgent:ignore_statis(name)
    self.ignore_statistics[name] = true
end

function ProxyAgent:statistics(event, name, ...)
    if self.ignore_statistics[name] then
        return
    end
    self:send(event, name, ...)
end

function ProxyAgent:send(rpc, ...)
    if scheduler then
        return scheduler:send("proxy", rpc, ...)
    end
    if WTITLE ~= "proxy" then
        return send_worker("proxy", rpc, ...)
    end
    event_mgr:notify_listener(rpc, ...)
end

function ProxyAgent:call(rpc, ...)
    if scheduler then
        return scheduler:call("proxy", rpc, ...)
    end
    if WTITLE ~= "proxy" then
        return call_worker("proxy", rpc, ...)
    end
    local rpc_datas = event_mgr:notify_listener(rpc, ...)
    return tunpack(rpc_datas)
end

quanta.proxy_agent = ProxyAgent()

return ProxyAgent
