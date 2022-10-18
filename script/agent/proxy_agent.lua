--proxy_agent.lua
local sformat       = string.format

local scheduler     = quanta.get("scheduler")

local ProxyAgent    = singleton()

function ProxyAgent:__init()
    --启动代理线程
    scheduler:startup("proxy", "proxy")
    --日志上报
    if environ.status("QUANTA_LOG_REPORT") then
        logger.add_monitor(self)
    end
end

--日志分发
function ProxyAgent:dispatch_log(content, lvl_name, lvl)
    local title = sformat("%s | %s", quanta.service_name, lvl_name)
    scheduler:send("proxy", "rpc_dispatch_log", title, content, lvl)
end

quanta.proxy_agent = ProxyAgent()

return ProxyAgent
