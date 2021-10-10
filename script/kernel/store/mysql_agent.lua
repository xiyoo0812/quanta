--mysql_agent.lua
local env_number        = environ.number

local router_mgr        = quanta.get("router_mgr")

local DBGroup           = enum("DBGroup")
local DBGROUP_AREA      = DBGroup.AREA

local MysqlAgent = singleton()
function MysqlAgent:__init()
    self.area_id = env_number("QUANTA_AREA_ID")
end

--发送数据库请求
function MysqlAgent:execute(hash_key, sql, db_group, db_area)
    return router_mgr:call_mysql_hash(hash_key, "mysql_execute", db_group or DBGROUP_AREA, db_area or self.area_id, sql)
end

------------------------------------------------------------------
quanta.mysql_agent = MysqlAgent()

return MysqlAgent
