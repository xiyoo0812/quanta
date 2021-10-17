--redis_agent.lua
local tunpack           = table.unpack

local router_mgr        = quanta.get("router_mgr")

local RedisAgent = singleton()
function RedisAgent:__init()
end

--发送数据库请求
--db_query: { cmd, ...}
function RedisAgent:execute(hash_key, db_query, db_name)
    return router_mgr:call_redis_hash(hash_key, "redis_execute", db_name or "default", tunpack(db_query))
end

------------------------------------------------------------------
quanta.redis_agent = RedisAgent()

return RedisAgent
