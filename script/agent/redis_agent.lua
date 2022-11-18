--redis_agent.lua
local tunpack       = table.unpack
local mrandom       = qmath.random

local router_mgr    = quanta.get("router_mgr")

local MAIN_DBID     = environ.number("QUANTA_DB_MAIN_ID")

local RedisAgent = singleton()
function RedisAgent:__init()
end

--发送数据库请求
--db_query: { cmd, ...}
function RedisAgent:execute(db_query, hash_key, db_id)
    return router_mgr:call_redis_hash(hash_key or mrandom(), "rpc_redis_execute", db_id or MAIN_DBID, tunpack(db_query))
end

------------------------------------------------------------------
quanta.redis_agent = RedisAgent()

return RedisAgent
