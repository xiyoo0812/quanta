-- cache_agent.lua

local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn
local hash_code     = utility.hash_code
local check_failed  = utility.check_failed
local env_number    = environ.number

local KernCode      = enum("KernCode")

local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")

local CacheAgent = singleton()
local prop = property(CacheAgent)
prop:accessor("area_num", 1)        -- area的数量
prop:accessor("cache_num", 1)       -- cache的数量
prop:accessor("cache_svrs", {})     -- map<cid, quanta_id>
function CacheAgent:__init()
    self.area_id = env_number("QUANTA_AREA_ID")
    self.cache_num = env_number("QUANTA_CACHE_COUNT")

    router_mgr:watch_service_ready(self, "cachesvr")
    router_mgr:watch_service_close(self, "cachesvr")
end

-- 加载
function CacheAgent:load(primary_key, cache_name, db_area)
    local load_db_area = self:find_db_area(db_area)
    local cachesvr_id = self:find_cachesvr_id(primary_key, load_db_area)
    if not cachesvr_id then
        log_err("[CacheAgent][find] cachesvr not online: primary_key=%s,cache_name=%s", primary_key, cache_name)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_key }
    local ok, code, row_data = router_mgr:call_target(cachesvr_id, "rpc_cache_load", quanta.id, load_db_area, req_data)
    if not ok or check_failed(code) then
        log_warn("[CacheAgent][find] code=%s,pkey=%s,cache=%s", code, primary_key, cache_name)
        return ok and code or KernCode.RPC_FAILED
    end
    return code, row_data
end

-- 修改
function CacheAgent:update(primary_key, table_name, table_data, cache_name, flush, db_area)
    local area_id = self:find_db_area(db_area)
    local cachesvr_id = self:find_cachesvr_id(primary_key, area_id)
    if not cachesvr_id then
        log_err("[CacheAgent][update] cachesvr not online: cache_name=%s,table_name=%s,primary_key=%s", cache_name, table_name, primary_key)
        return KernCode.RPC_FAILED
    end
    local req_data = { cache_name or "player", primary_key, table_name, table_data, flush }
    local ok, code = router_mgr:call_target(cachesvr_id, "rpc_cache_update", quanta.id, req_data)
    if not ok or check_failed(code) then
        log_err("[CacheAgent][update] faild: code=%s cache_name=%s,table_name=%s,primary_key=%s", code, cache_name, table_name, primary_key)
        return ok and code or KernCode.RPC_FAILED
    end
    return code
end

-- 修改kv
function CacheAgent:update_key(primary_key, table_name, table_key, table_value, cache_name, flush, db_area)
    local area_id = self:find_db_area(db_area)
    local cachesvr_id = self:find_cachesvr_id(primary_key, area_id)
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
function CacheAgent:delete(primary_key, cache_name, db_area)
    local area_id = self:find_db_area(db_area)
    local cachesvr_id = self:find_cachesvr_id(primary_key, area_id)
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

-- flush
function CacheAgent:flush(primary_key, cache_name, db_area)
    local area_id = self:find_db_area(db_area)
    local cachesvr_id = self:find_cachesvr_id(primary_key, area_id)
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

-- 重建
function CacheAgent:rebuild(primary_keys, cache_name)
    local cachesvr_id = self:find_cachesvr_id(primary_keys, self.area_id)
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

-- 服务器上线
function CacheAgent:on_service_ready(quanta_id, service_name)
    log_info("[CacheAgent][on_service_ready] id=%s, service_name=%s", quanta_id, service_name)
    -- 获取上线的数据节点哈希配置（哈希值和总数）
    local ok, code, res = router_mgr:call_target(quanta_id, "rpc_load_cache_hash", quanta.id, quanta.service)
    if not ok or check_failed(code) then
        log_err("[CacheAgent][on_service_ready] load_cache failed! id=%s, service_name=%s", quanta_id, service_name)
        return
    end
    local cache_area, cache_hash = res.cache_area, res.cache_hash
    if not self.cache_svrs[cache_area] then
        self.cache_svrs[cache_area] = {}
    end
    if cache_area > self.area_num then
        self.area_num = cache_area
    end
    local cache_key = self:build_hash_key(cache_hash, cache_area)
    self.cache_svrs[cache_key] = quanta_id
    log_info("[CacheAgent][on_service_ready] add cachesvr node: cache_area=%s, hash_key=%s", cache_area, cache_hash)
    --通知缓存重建
    if cache_area == self.area_id then
        event_mgr:notify_listener("evt_cache_rebuild", cache_hash, self.cache_num)
    end
end

-- 服务器掉线
function CacheAgent:on_service_close(quanta_id, service_name)
    log_info("[CacheAgent][on_service_close] id=%s, service_name=%s", quanta_id, service_name)
    for hash_key, cache_quanta_id in pairs(self.cache_svrs) do
        if cache_quanta_id == quanta_id then
            self.cache_svrs[hash_key] = nil
            break
        end
    end
end

--find db_area
function CacheAgent:find_db_area(db_area)
    if not db_area then
        return self.area_id
    end
    if type(db_area) == "number" then
        return db_area
    end
    return hash_code(db_area, self.area_num)
end

--构建cache_key
function CacheAgent:build_hash_key(cache_id, hash_key)
    return cache_id * 1000 + hash_key
end

--根据小区和哈希key获取对应的cachesvr节点id
function CacheAgent:find_cachesvr_id(primary_key, area_id)
    local hash_key = hash_code(primary_key, self.cache_num)
    local cache_key = self:build_hash_key(hash_key, area_id)
    return self.cache_svrs[cache_key]
end

-- export
quanta.cache_agent = CacheAgent()

return CacheAgent
