--redis_agent.lua
local tunpack       = table.unpack
local mrandom       = qmath.random

local router_mgr    = quanta.get("router_mgr")

local RedisAgent = singleton()
function RedisAgent:__init()
end

--发送数据库请求
--db_query: { cmd, ...}
function RedisAgent:execute(db_query, hash_key)
    local key = hash_key or mrandom()
    return router_mgr:call_redis_hash(key, "rpc_redis_execute", tunpack(db_query))
end


function RedisAgent:autoinc_id()
    return router_mgr:call_redis_hash(mrandom(), "rpc_redis_autoinc_id")
end

------------------------------------------------------------------
quanta.redis_agent = RedisAgent()

return RedisAgent
