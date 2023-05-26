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
        log_err("[CacheAgent][load] code=%s, pkey=%s, sheet_name=%s", code, primary_id, sheet_name)
        return ok and code or RPC_FAILED
    end
    return code, row_data
end

-- 修改fields
function CacheAgent:update_field(primary_id, sheet_name, field, field_data)
    local ok, code = router_mgr:call_cache_hash(primary_id, "rpc_cache_update_field", primary_id, sheet_name, field, field_data)
    if qfailed(code, ok) then
        log_err("[CacheAgent][update_field] faild: code=%s, sheet_name=%s, primary_id=%s", code, sheet_name, primary_id)
        return ok and code or RPC_FAILED
    end
    return code
end

-- 删除fields
function CacheAgent:remove_field(primary_id, sheet_name, field)
    local ok, code = router_mgr:call_cache_hash(primary_id, "rpc_cache_remove_field", primary_id, sheet_name, field)
    if qfailed(code, ok) then
        log_err("[CacheAgent][remove_field] faild: code=%s, sheet_name=%s, primary_id=%s", code, sheet_name, primary_id)
        return ok and code or RPC_FAILED
    end
    return code
end

-- 删除
function CacheAgent:delete(primary_id, sheet_name)
    local ok, code = router_mgr:call_cache_hash(primary_id, "rpc_cache_delete", primary_id, sheet_name)
    if qfailed(code, ok) then
        log_err("[CacheAgent][delete] faild: code=%s, sheet_name=%s, primary_id=%s", code, sheet_name, primary_id)
        return ok and code or RPC_FAILED
    end
    return code
end

-- export
quanta.cache_agent = CacheAgent()

return CacheAgent
