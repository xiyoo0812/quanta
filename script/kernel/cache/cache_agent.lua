-- data_agent.lua

local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn
local hash_code     = utility.hash_code
local check_failed  = utility.check_failed
local env_number    = environ.number

local KernCode      = enum("KernCode")

local event_mgr     = quanta.event_mgr
local router_mgr    = quanta.router_mgr

local CacheAgent = singleton()
local prop = property(CacheAgent)
prop:accessor("cache_count", 1)     -- cache的数量
prop:accessor("cache_svrs", {})     -- map<cid, quanta_id>
function CacheAgent:__init()
    self.cache_id = env_number("QUANTA_PART_ID")
    self.cache_count = env_number("QUANTA_CACHE_COUNT")

    router_mgr:watch_service_ready(self, "cachesvr")
    router_mgr:watch_service_close(self, "cachesvr")
end

-- 加载
function CacheAgent:load(primary_key, cache_name)
    local cachesvr_id = self:find_cachesvr_id(primary_key)
    if not cachesvr_id then
        log_err("[CacheAgent][find] cachesvr not online: primary_key=%s,cache_name=%s", primary_key, cache_name)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_key }
    local ok, code, row_data = router_mgr:call_target(cachesvr_id, "rpc_cache_load", quanta.id, req_data)
    if not ok or check_failed(code) then
        log_warn("[CacheAgent][find] code=%s,pkey=%s,cache=%s", code, primary_key, cache_name)
        return ok and code or KernCode.RPC_FAILED
    end
    return code, row_data
end

-- 修改
function CacheAgent:update(primary_key, table_name, table_data, cache_name)
    local cachesvr_id = self:find_cachesvr_id(primary_key)
    if not cachesvr_id then
        log_err("[CacheAgent][update] cachesvr not online: cache_name=%s,table_name=%s,primary_key=%s", cache_name, table_name, primary_key)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_key, table_name, table_data }
    local ok, code = router_mgr:call_target(cachesvr_id, "rpc_cache_update", quanta.id, req_data)
    if not ok or check_failed(code) then
        log_err("[CacheAgent][update] faild: code=%s cache_name=%s,table_name=%s,primary_key=%s", code, cache_name, table_name, primary_key)
        return ok and code or KernCode.RPC_FAILED
    end
    return code
end

-- 修改kv
function CacheAgent:update_key(primary_key, table_name, table_key, table_value, cache_name)
    local cachesvr_id = self:find_cachesvr_id(primary_key)
    if not cachesvr_id then
        log_err("[CacheAgent][update_key] cachesvr not online: cache_name=%s,table_name=%s,primary_key=%s", cache_name, table_name, primary_key)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_key, table_name, table_key, table_value }
    local ok, code = router_mgr:call_target(cachesvr_id, "rpc_cache_update_key", quanta.id, req_data)
    if not ok or check_failed(code) then
        log_err("[CacheAgent][update_key] faild: code=%s,cache_name=%s,table_name=%s,primary_key=%s", code, cache_name, table_name, primary_key)
        return ok and code or KernCode.RPC_FAILED
    end
    return code
end

-- 删除
function CacheAgent:delete(primary_key, cache_name)
    local cachesvr_id = self:find_cachesvr_id(primary_key)
    if not cachesvr_id then
        log_err("[CacheAgent][delete] cachesvr not online: cache_name=%s,primary_key=%s", cache_name, primary_key)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_key }
    local ok, code = router_mgr:call_target(cachesvr_id, "rpc_cache_delete", quanta.id, req_data)
    if not ok or check_failed(code) then
        log_err("[CacheAgent][delete] faild: code=%s,cache_name=%s,primary_key=%s", code, cache_name, primary_key)
        return ok and code or KernCode.RPC_FAILED
    end
    return code
end

-- 重建
function CacheAgent:rebuild(primary_keys, cache_name)
    local cachesvr_id = self:find_cachesvr_id(primary_keys)
    if not cachesvr_id then
        log_err("[CacheAgent][rebuild] cachesvr not online: cache_name=%s,primary_keys=%s", cache_name, primary_keys)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_keys }
    local ok, code = router_mgr:call_target(cachesvr_id, "rpc_cache_rebuild", quanta.id, req_data)
    if not ok or check_failed(code) then
        log_err("[CacheAgent][rebuild] faild: code=%s,cache_name=%s,primary_keys=%s", code, cache_name, primary_keys)
        return ok and code or KernCode.RPC_FAILED
    end
    return code
end

-- flush
function CacheAgent:flush(primary_key, cache_name)
    local cachesvr_id = self:find_cachesvr_id(primary_key)
    if not cachesvr_id then
        log_err("[CacheAgent][flush] cachesvr not online: cache_name=%s,primary_key=%s", cache_name, primary_key)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_key }
    local ok, code = router_mgr:call_target(cachesvr_id, "rpc_cache_flush", quanta.id, req_data)
    if not ok or check_failed(code) then
        log_err("[CacheAgent][flush] faild: code=%s,cache_name=%s,primary_key=%s", code, cache_name, primary_key)
        return ok and code or KernCode.RPC_FAILED
    end
    return code
end

-- 服务器上线
function CacheAgent:on_service_ready(quanta_id, service_name)
    log_info("[CacheAgent][on_service_ready] id=%s, service_name=%s", quanta_id, service_name)
    -- 获取上线的数据节点哈希配置（哈希值和总数）
    local ok, code, res = router_mgr:call_target(quanta_id, "rpc_load_cache_hash", quanta.id, quanta.service)
    if not ok or check_failed(code) then
        log_err("[CacheAgent][on_service_ready] load_cache failed! id=%s, service_name=%s", quanta_id, service_name)
        return
    end
    if self.cache_id ~= res.cache_id then
        log_err("[CacheAgent][on_service_ready] load_cache cache_id not match! id=%s, cache_id=%s", quanta_id, res.cache_id)
        return
    end
    self.cache_svrs[res.cache_hash] = res.quanta_id
    log_info("[CacheAgent][on_service_ready] add cachesvr node: cache_id=%s, hash_key=%s", res.cache_id, res.cache_hash)
    --通知缓存重建
    event_mgr:notify_listener("evt_cache_rebuild", res.cache_hash, self.cache_count)
end

-- 服务器掉线
function CacheAgent:on_service_close(quanta_id, service_name)
    log_info("[CacheAgent][on_service_close] id=%s, service_name=%s", quanta_id, service_name)
    for hash_key, cache_quanta_id in pairs(self.cache_svrs) do
        if cache_quanta_id == quanta_id then
            self.cache_svrs[hash_key] = nil
            return
        end
    end
end

--根据小区和哈希key获取对应的cachesvr节点id
--返回节点的quanta_id或者nil
function CacheAgent:find_cachesvr_id(hash_key)
    local key = hash_code(hash_key, self.cache_count)
    return self.cache_svrs[key]
end

-- export
quanta.cache_agent = CacheAgent()

return CacheAgent
