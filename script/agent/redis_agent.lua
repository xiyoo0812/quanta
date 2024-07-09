--redis_agent.lua
local log_err       = logger.err
local tunpack       = table.unpack
local mrandom       = qmath.random
local sformat       = string.format
local qfailed       = quanta.failed

local router_mgr    = quanta.get("router_mgr")
local CLUSTER       = environ.get("QUANTA_CLUSTER")
local MSIC_PREFIX   = sformat("QUANTA:%s:MSIC", CLUSTER)

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

--保存变量
function RedisAgent:save_msic(key, value)
    return self:execute({"HSET", MSIC_PREFIX, key, value} )
end

--加载变量
function RedisAgent:load_msic(key)
    local ok, code, result = self:execute({ "HGETALL", MSIC_PREFIX })
    if qfailed(code, ok) then
        log_err("[RedisAgent][load_msic] failed! ok: %s, code: %s", ok, code)
        return nil
    end
    if not key then
        return result
    end
    return result[key]
end

------------------------------------------------------------------
quanta.redis_agent = RedisAgent()

return RedisAgent
