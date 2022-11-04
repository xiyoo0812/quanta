-- cache_agent.lua

local log_err       = logger.err
local qfailed       = quanta.failed

local router_mgr    = quanta.get("router_mgr")

local RPC_FAILED    = quanta.enum("KernCode", "RPC_FAILED")

local CacheAgent = singleton()
function CacheAgent:__init()
end

-- 查询
function CacheAgent:find(primary_key, coll_name)
    local ok, code, row_data = router_mgr:call_cachesvr_hash(primary_key, "rpc_cache_find", primary_key, coll_name)
    if qfailed(code, ok) then
        log_err("[CacheAgent][find] code=%s, pkey=%s, coll_name=%s", code, primary_key, coll_name)
        return ok and code or RPC_FAILED
    end
    return code, row_data
end

-- 加载
function CacheAgent:load(primary_key, coll_name)
    local ok, code, row_data = router_mgr:call_cachesvr_hash(primary_key, "rpc_cache_load", quanta.id, primary_key, coll_name)
    if qfailed(code, ok) then
        log_err("[CacheAgent][load] code=%s, pkey=%s, coll_name=%s", code, primary_key, coll_name)
        return ok and code or RPC_FAILED
    end
    return code, row_data
end

-- 修改
function CacheAgent:update(primary_key, coll_name, coll_data, flush)
    local ok, code = router_mgr:call_cachesvr_hash(primary_key, "rpc_cache_update", quanta.id, primary_key, coll_name, coll_data, flush)
    if qfailed(code, ok) then
        log_err("[CacheAgent][update] faild: code=%s, coll_name=%s, primary_key=%s", code, coll_name, primary_key)
        return ok and code or RPC_FAILED
    end
    return code
end

-- 修改fields
function CacheAgent:update_fields(primary_key, coll_name, coll_fields, flush)
    local ok, code = router_mgr:call_cachesvr_hash(primary_key, "rpc_cache_update_fields", quanta.id, primary_key, coll_name, coll_fields, flush)
    if qfailed(code, ok) then
        log_err("[CacheAgent][update_fields] faild: code=%s, coll_name=%s, primary_key=%s", code, coll_name, primary_key)
        return ok and code or RPC_FAILED
    end
    return code
end

-- 删除fields
function CacheAgent:remove_fields(primary_key, coll_name, coll_fields, flush)
    local ok, code = router_mgr:call_cachesvr_hash(primary_key, "rpc_cache_remove_fields", quanta.id, primary_key, coll_name, coll_fields, flush)
    if qfailed(code, ok) then
        log_err("[CacheAgent][update_key] faild: code=%s, coll_name=%s, primary_key=%s", code, coll_name, primary_key)
        return ok and code or RPC_FAILED
    end
    return code
end

-- 删除
function CacheAgent:delete(primary_key, coll_name)
    local ok, code = router_mgr:call_cachesvr_hash(primary_key, "rpc_cache_delete", quanta.id, primary_key, coll_name)
    if qfailed(code, ok) then
        log_err("[CacheAgent][delete] faild: code=%s, coll_name=%s, primary_key=%s", code, coll_name, primary_key)
        return ok and code or RPC_FAILED
    end
    return code
end

-- flush
function CacheAgent:flush(primary_key, group)
    local ok, code = router_mgr:call_cachesvr_hash(primary_key, "rpc_cache_flush", primary_key, group)
    if qfailed(code, ok) then
        log_err("[CacheAgent][flush] faild: code=%s, group=%s, primary_key=%s", code, group, primary_key)
        return ok and code or RPC_FAILED
    end
    return code
end

-- export
quanta.cache_agent = CacheAgent()

return CacheAgent
