--redis_agent.lua
local tunpack           = table.unpack
local env_number        = environ.number

local router_mgr        = quanta.get("router_mgr")

local DBGroup           = enum("DBGroup")
local DBGROUP_AREA      = DBGroup.AREA

local RedisAgent = singleton()
function RedisAgent:__init()
    self.area_id = env_number("QUANTA_AREA_ID")
end

--发送数据库请求
--db_query: {cmd, ...}
function RedisAgent:execute(hash_key, db_query, db_group, db_area)
    return router_mgr:call_redis_hash(hash_key, "redis_execute", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

------------------------------------------------------------------
quanta.redis_agent = RedisAgent()

return RedisAgent
