-- data_agent.lua

local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn
local hash_code     = utility.hash_code
local check_failed  = utility.check_failed

local KernCode      = enum("KernCode")

local event_mgr     = quanta.event_mgr
local router_mgr    = quanta.router_mgr

local CacheAgent = singleton()
function CacheAgent:__init()
    self._pid2dids   = {} -- 小区id映射index map<pid, map<hid, quanta_id>>
    self._pid2dcount = {} -- 每个小区id对应的data节点数量

    router_mgr:watch_service_ready(self, "cachesvr")
    router_mgr:watch_service_close(self, "cachesvr")
end

-- 加载
function CacheAgent:load(db_id, primary_key, cache_name)
    local cachesvr_id = self:_find_cachesvr_id(db_id, primary_key)
    if not cachesvr_id then
        log_err("[CacheAgent][find] cachesvr not online: pid=%s,key=%s", db_id, primary_key)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_key }
    local ok, ec, row_data = router_mgr:call_target(cachesvr_id, "rpc_cache_load", quanta.id, req_data)
    if not ok or check_failed(ec) then
        log_warn("[CacheAgent][find] ec=%s,pkey=%s,cache=%s", ec, primary_key, cache_name)
        return ok and ec or KernCode.RPC_FAILED
    end
    return ec, row_data
end

-- 修改
function CacheAgent:update(db_id, primary_key, table_name, table_data, cache_name)
    local cachesvr_id = self:_find_cachesvr_id(db_id, primary_key)
    if not cachesvr_id then
        log_err("[CacheAgent][update] cachesvr not online: pid=%s,table=%s,key=%s", db_id, table_name, primary_key)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_key, table_name, table_data }
    local ok, ec = router_mgr:call_target(cachesvr_id, "rpc_cache_update", quanta.id, req_data)
    if not ok or check_failed(ec) then
        log_err("[CacheAgent][update] faild: ec=%s,pid=%s,table=%s,key=%s", ec, db_id, table_name, primary_key)
        return ok and ec or KernCode.RPC_FAILED
    end
    return ec
end

-- 修改kv
function CacheAgent:update_key(db_id, primary_key, table_name, table_key, table_value, cache_name)
    local cachesvr_id = self:_find_cachesvr_id(db_id, primary_key)
    if not cachesvr_id then
        log_err("[CacheAgent][update_key] cachesvr not online: pid=%s,table=%s,key=%s", db_id, table_name, primary_key)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_key, table_name, table_key, table_value }
    local ok, ec = router_mgr:call_target(cachesvr_id, "rpc_cache_update_key", quanta.id, req_data)
    if not ok or check_failed(ec) then
        log_err("[CacheAgent][update_key] faild: ec=%s,pid=%s,table=%s,key=%s", ec, db_id, table_name, primary_key)
        return ok and ec or KernCode.RPC_FAILED
    end
    return ec
end

-- 删除
function CacheAgent:delete(db_id, primary_key, cache_name)
    local cachesvr_id = self:_find_cachesvr_id(db_id, primary_key)
    if not cachesvr_id then
        log_err("[CacheAgent][delete] cachesvr not online: pid=%s,key=%s", db_id, primary_key)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_key }
    local ok, ec = router_mgr:call_target(cachesvr_id, "rpc_cache_delete", quanta.id, req_data)
    if not ok or check_failed(ec) then
        log_err("[CacheAgent][delete] faild: ec=%s,pid=%s,key=%s", ec, db_id, primary_key)
        return ok and ec or KernCode.RPC_FAILED
    end
    return ec
end

-- 重建
function CacheAgent:rebuild(db_id, primary_keys, cache_name)
    local cachesvr_id = self:_find_cachesvr_id(db_id, primary_keys)
    if not cachesvr_id then
        log_err("[CacheAgent][rebuild] cachesvr not online: pid=%s,key=%s", db_id, primary_keys)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_keys }
    local ok, ec = router_mgr:call_target(cachesvr_id, "rpc_cache_rebuild", quanta.id, req_data)
    if not ok or check_failed(ec) then
        log_err("[CacheAgent][rebuild] faild: ec=%s,pid=%s,key=%s", ec, db_id, primary_keys)
        return ok and ec or KernCode.RPC_FAILED
    end
    return ec
end

-- flush
function CacheAgent:flush(db_id, primary_key, cache_name)
    local cachesvr_id = self:_find_cachesvr_id(db_id, primary_key)
    if not cachesvr_id then
        log_err("[CacheAgent][flush] cachesvr not online: pid=%s,key=%s", db_id, primary_key)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_key }
    local ok, ec = router_mgr:call_target(cachesvr_id, "rpc_cache_flush", quanta.id, req_data)
    if not ok or check_failed(ec) then
        log_err("[CacheAgent][flush] faild: ec=%s,pid=%s,key=%s", ec, db_id, primary_key)
        return ok and ec or KernCode.RPC_FAILED
    end
    return ec
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
    if not self._pid2dcount[res.db_id] then
        self._pid2dcount[res.db_id] = res.db_count
    end
    log_info("[CacheAgent][on_service_ready] add cachesvr node: db_id=%s, hash_key=%s", res.db_id, res.db_hash)
    self:_insert_cachesvr_id(res.db_id, res.db_hash, res.quanta_id)
    --通知缓存重建
    event_mgr:notify_listener("evt_cache_rebuild", res.db_hash, res.db_count)
end

-- 服务器掉线
function CacheAgent:on_service_close(quanta_id, service_name)
    log_info("[CacheAgent][on_service_close] id=%s, service_name=%s", quanta_id, service_name)
    for _, ids in pairs(self._pid2dids) do
        for hash_key, data_id in pairs(ids) do
            if data_id == quanta_id then
                ids[hash_key] = nil
                return
            end
        end
    end
end

--根据小区和哈希key获取对应的cachesvr节点id
--返回节点的quanta_id或者nil
function CacheAgent:_find_cachesvr_id(db_id, hash_key)
    --获取小区对应的id列表
    local ids = self._pid2dids[db_id]
    if ids then
        local count = self._pid2dcount[db_id]
        local key = hash_code(hash_key) % count + 1
        return ids[key]
    end
end

-- 插入小区和哈希key对应的cachesvr节点id
function CacheAgent:_insert_cachesvr_id(db_id, hash_key, quanta_id)
    local ids = self._pid2dids[db_id]
    if not ids then
        ids = {}
        self._pid2dids[db_id] = ids
    end
    ids[hash_key] = quanta_id
end

-- export
quanta.cache_agent = CacheAgent()

return CacheAgent
