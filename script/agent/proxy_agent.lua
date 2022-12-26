--proxy_agent.lua
local sformat       = string.format

local scheduler     = quanta.get("scheduler")

local ProxyAgent    = singleton()

function ProxyAgent:__init()
    --启动代理线程
    scheduler:startup("proxy", "proxy")
end

--webhook
function ProxyAgent:fire_webhook(content, lvl_name, lvl)
    local title = sformat("%s | %s", quanta.service_name, lvl_name)
    scheduler:send("proxy", "rpc_fire_webhook", title, content, lvl)
end

--http_get
function ProxyAgent:http_get(url, querys, headers)
    return scheduler:call("proxy", "rpc_http_get", url, querys, headers)
end

--http_post
function ProxyAgent:http_post(url, post_data, headers, querys)
    return scheduler:call("proxy", "rpc_http_post", url, post_data, headers, querys)
end

--http_put
function ProxyAgent:http_put(url, put_data, headers, querys)
    return scheduler:call("proxy", "rpc_http_put", url, put_data, headers, querys)
end

--http_del
function ProxyAgent:http_del(url, querys, headers)
    return scheduler:call("proxy", "rpc_http_del", url, querys, headers)
end

quanta.proxy_agent = ProxyAgent()

return ProxyAgent
