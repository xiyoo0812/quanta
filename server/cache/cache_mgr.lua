-- cache_mgr.lua
import("store/mongo_mgr.lua")
local Collection    = import("cache/collection.lua")

local log_err       = logger.err
local log_info      = logger.info
local qfailed       = quanta.failed

local event_mgr     = quanta.get("event_mgr")
local timer_mgr     = quanta.get("timer_mgr")
local config_mgr    = quanta.get("config_mgr")

local cache_db      = config_mgr:init_table("cache", "coll_name")

local SUCCESS               = quanta.enum("KernCode", "SUCCESS")
local SECOND_MS             = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_10_MS          = quanta.enum("PeriodTime", "SECOND_10_MS")
local CacheMgr = singleton()
local prop = property(CacheMgr)
prop:reader("collections", {})        -- collections

function CacheMgr:__init()
    -- 监听rpc事件
    event_mgr:add_listener(self, "rpc_cache_find")
    event_mgr:add_listener(self, "rpc_cache_load")
    event_mgr:add_listener(self, "rpc_cache_update")
    event_mgr:add_listener(self, "rpc_cache_update_fields")
    event_mgr:add_listener(self, "rpc_cache_remove_fields")
    event_mgr:add_listener(self, "rpc_cache_delete")
    event_mgr:add_listener(self, "rpc_cache_flush")
    --定时器
    timer_mgr:loop(SECOND_MS, function(ms)
        self:on_timer_update(ms)
    end)
    timer_mgr:loop(SECOND_10_MS, function(ms)
        self:on_timer_expire(ms)
    end)
end

--更新数据
function CacheMgr:on_timer_update()
    local now_tick = quanta.now
    for _, collection in pairs(self.collections) do
        if collection:check_store(now_tick) then
            collection:save()
        end
    end
end

--清理超时的记录
function CacheMgr:on_timer_expire()
    local now_tick = quanta.now
    for _, collection in pairs(self.collections) do
        collection:check_expired(now_tick)
    end
end

function CacheMgr:find_collection(coll_name)
    local collection = self.collections[coll_name]
    if not collection then
        local conf = cache_db:find_one(coll_name)
        collection = Collection(conf)
        self.collections[coll_name] = collection
    end
    return collection
end

function CacheMgr:rpc_cache_load(quanta_id, primary_key, coll_name)
    local collection = self:find_collection(coll_name)
    local code, doc = collection:load(primary_key)
    if qfailed(code) then
        log_err("[CacheMgr][rpc_cache_load] doc not find! coll_name=%s, primary=%s", coll_name, primary_key)
        return code
    end
    doc:set_lock_node_id(quanta_id)
    log_info("[CacheMgr][rpc_cache_load] coll_name=%s, primary=%s", coll_name, primary_key)
    return code, doc:get_data()
end

--更新缓存
function CacheMgr:rpc_cache_update(quanta_id, primary_key, coll_name, coll_data, flush)
    local collection = self:find_collection(coll_name)
    local code = collection:update(primary_key, coll_data, flush)
    if qfailed(code) then
        log_err("[CacheMgr][rpc_cache_update] update failed! coll_name=%s, primary=%s", coll_name, primary_key)
    end
    return code
end

--更新缓存kv
function CacheMgr:rpc_cache_update_fields(quanta_id, primary_key, coll_name, coll_fields, flush)
    local collection = self:find_collection(coll_name)
    local code = collection:update_fields(primary_key, coll_fields, flush)
    if qfailed(code) then
        log_err("[CacheMgr][rpc_cache_update_fields] update fields failed! coll_name=%s, primary=%s", coll_name, primary_key)
    end
    return code
end

--更新缓存kv
function CacheMgr:rpc_cache_remove_fields(quanta_id, primary_key, coll_name, coll_fields, flush)
    local collection = self:find_collection(coll_name)
    local code = collection:remove_fields(primary_key, coll_fields, flush)
    if qfailed(code) then
        log_err("[CacheMgr][rpc_cache_remove_fields] remove fields failed! coll_name=%s, primary=%s", coll_name, primary_key)
    end
    return code
end

--删除缓存，通常由运维指令执行
function CacheMgr:rpc_cache_delete(quanta_id, primary_key, coll_name)
    local collection = self:find_collection(coll_name)
    local code = collection:delete(primary_key, primary_key)
    if qfailed(code) then
        log_err("[CacheMgr][rpc_cache_delete] delete failed! coll_name=%s, primary=%s", coll_name, primary_key)
    end
    return code
end

--缓存落地
function CacheMgr:rpc_cache_flush(primary_key, group)
    for _, collection in pairs(self.collections) do
        if group == collection:get_group() then
            local code = collection:save(primary_key)
            if qfailed(code) then
                log_err("[CacheMgr][rpc_cache_flush] doc not find! primary=%s", primary_key)
                return code
            end
        end
    end
    log_err("[CacheMgr][rpc_cache_flush] save failed: primary=%s", primary_key)
    return SUCCESS
end

quanta.cache_mgr = CacheMgr()

return CacheMgr
