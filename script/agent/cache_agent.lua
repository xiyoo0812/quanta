-- cache_agent.lua

local log_err       = logger.err
local qfailed       = quanta.failed

local router_mgr    = quanta.get("router_mgr")

local RPC_FAILED    = quanta.enum("KernCode", "RPC_FAILED")

local CacheAgent = singleton()

function CacheAgent:__init()
end

-- 加载
function CacheAgent:load(primary_id, sheet_name)
    local ok, code, row_data = router_mgr:call_cache_hash(primary_id, "rpc_cache_load", primary_id, sheet_name)
    if qfailed(code, ok) then
        log_err("[CacheAgent][load] code={}, pkey={}, sheet_name={}", code, primary_id, sheet_name)
        return ok and code or RPC_FAILED
    end
    return code, row_data
end

-- flush
function CacheAgent:flush(primary_id, sheet_name, wholes)
    local ok, code = router_mgr:call_cache_hash(primary_id, "rpc_cache_flush", primary_id, sheet_name, wholes)
    if qfailed(code, ok) then
        log_err("[CacheAgent][flush] faild: code={}, sheet_name={}, primary_id={}", code, sheet_name, primary_id)
        return ok and code or RPC_FAILED
    end
    return code
end

-- update
function CacheAgent:update(primary_id, sheet_name, commits)
    local ok, code = router_mgr:call_cache_hash(primary_id, "rpc_cache_update", primary_id, sheet_name, commits)
    if qfailed(code, ok) then
        log_err("[CacheAgent][update] faild: code={}, sheet_name={}, primary_id={}", code, sheet_name, primary_id)
        return ok and code or RPC_FAILED
    end
    return code
end

-- 删除
function CacheAgent:delete(primary_id, sheet_name)
    local ok, code = router_mgr:call_cache_hash(primary_id, "rpc_cache_delete", primary_id, sheet_name)
    if qfailed(code, ok) then
        log_err("[CacheAgent][delete] faild: code={}, sheet_name={}, primary_id={}", code, sheet_name, primary_id)
        return ok and code or RPC_FAILED
    end
    return code
end

-- export
quanta.cache_agent = CacheAgent()

return CacheAgent
