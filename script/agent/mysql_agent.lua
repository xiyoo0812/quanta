--mysql_agent.lua
local mrandom       = math.random

local router_mgr    = quanta.get("router_mgr")

local MysqlAgent = singleton()
function MysqlAgent:__init()
end

--发送数据库请求
function MysqlAgent:execute(sql, hash_key, db_name)
    return router_mgr:call_mysql_hash(hash_key or mrandom(10000), "mysql_execute", db_name or "default", sql)
end

------------------------------------------------------------------
quanta.mysql_agent = MysqlAgent()

return MysqlAgent
