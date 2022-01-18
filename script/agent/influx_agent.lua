--influx_agent.lua

local router_mgr    = quanta.get("router_mgr")

local InfluxAgent = singleton()
function InfluxAgent:__init()
end

--发送数据库请求
--db_query: { cmd, ...}
function InfluxAgent:write(tags, fields, db_name)
    return router_mgr:call_influx_random("influx_write", db_name or "default", tags, fields)
end

--script
function InfluxAgent:query(script, db_name)
    return router_mgr:call_influx_random("influx_query", db_name or "default", script)
end

------------------------------------------------------------------
quanta.influx_agent = InfluxAgent()

return InfluxAgent
