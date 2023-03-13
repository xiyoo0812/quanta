-- cache_agent.lua

local log_err       = logger.err
local qfailed       = quanta.failed

local router_mgr    = quanta.get("router_mgr")

local RPC_FAILED    = quanta.enum("KernCode", "RPC_FAILED")

local CacheAgent = singleton()
function CacheAgent:__init()
end

-- 加载
function CacheAgent:load(primary_id, sheet_name, primary_key, filters, group)
    local ok, code, row_data = router_mgr:call_cachesvr_hash(primary_id, "rpc_cache_load", quanta.id, primary_id, sheet_name, primary_key, filters, group)
    if qfailed(code, ok) then
        log_err("[CacheAgent][load] code=%s, pkey=%s, sheet_name=%s, group=%s", code, primary_id, sheet_name, group)
        return ok and code or RPC_FAILED
    end
    return code, row_data
end

-- 修改fields
function CacheAgent:update_field(primary_id, sheet_name, field, field_data, flush)
    local ok, code = router_mgr:call_cachesvr_hash(primary_id, "rpc_cache_update", quanta.id, primary_id, sheet_name, field, field_data, flush)
    if qfailed(code, ok) then
        log_err("[CacheAgent][update_field] faild: code=%s, sheet_name=%s, primary_id=%s", code, sheet_name, primary_id)
        return ok and code or RPC_FAILED
    end
    return code
end

-- 删除fields
function CacheAgent:remove_field(primary_id, sheet_name, field, flush)
    local ok, code = router_mgr:call_cachesvr_hash(primary_id, "rpc_cache_remove_fields", quanta.id, primary_id, sheet_name, field, flush)
    if qfailed(code, ok) then
        log_err("[CacheAgent][remove_field] faild: code=%s, sheet_name=%s, primary_id=%s", code, sheet_name, primary_id)
        return ok and code or RPC_FAILED
    end
    return code
end

-- 删除
function CacheAgent:delete(primary_id, group)
    local ok, code = router_mgr:call_cachesvr_hash(primary_id, "rpc_cache_delete", quanta.id, primary_id, group)
    if qfailed(code, ok) then
        log_err("[CacheAgent][delete] faild: code=%s, group=%s, primary_id=%s", code, group, primary_id)
        return ok and code or RPC_FAILED
    end
    return code
end

-- flush
function CacheAgent:flush(primary_id, group)
    local ok, code = router_mgr:call_cachesvr_hash(primary_id, "rpc_cache_flush", primary_id, group)
    if qfailed(code, ok) then
        log_err("[CacheAgent][flush] faild: code=%s, group=%s, primary_id=%s", code, group, primary_id)
        return ok and code or RPC_FAILED
    end
    return code
end

-- export
quanta.cache_agent = CacheAgent()

return CacheAgent
