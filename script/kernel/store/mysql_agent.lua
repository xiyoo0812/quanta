--mysql_agent.lua
local router_mgr        = quanta.get("router_mgr")

local MysqlAgent = singleton()
function MysqlAgent:__init()
end

--发送数据库请求
function MysqlAgent:execute(hash_key, sql, db_name)
    return router_mgr:call_mysql_hash(hash_key, "mysql_execute", db_name or "default", sql)
end

------------------------------------------------------------------
quanta.mysql_agent = MysqlAgent()

return MysqlAgent
