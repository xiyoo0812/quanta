-- cache_mgr.lua
import("store/mongo_mgr.lua")

local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local qfailed       = quanta.failed

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local FRAME_SUCCESS = protobuf_mgr:error_code("FRAME_SUCCESS")
local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local CNOT_EXIST    = quanta.enum("CacheCode", "CACHE_IS_NOT_EXIST")
local DNOT_EXIST    = quanta.enum("CacheCode", "CACHE_KEY_NOT_EXIST")
local LOCK_FAILD    = quanta.enum("CacheCode", "CACHE_IS_LOCK_FAILD")
local DELETE_FAILD  = quanta.enum("CacheCode", "CACHE_DELETE_FAILD")

local Collection    = import("cache/collection.lua")

local CacheMgr = singleton()
local prop = property(CacheMgr)
prop:reader("collections", {})        -- collections

function CacheMgr:__init()
    -- 监听rpc事件
    event_mgr:add_listener(self, "rpc_cache_load")
    event_mgr:add_listener(self, "rpc_cache_update_field")
    event_mgr:add_listener(self, "rpc_cache_remove_field")
    event_mgr:add_listener(self, "rpc_cache_delete")
    event_mgr:add_listener(self, "rpc_cache_flush")
    event_mgr:add_listener(self, "rpc_server_close")
    --定时器
    update_mgr:attach_minute(self)
    update_mgr:attach_second5(self)
end

--更新数据
function CacheMgr:on_second5()
    local now_tick = quanta.now
    for _, collection in pairs(self.collections) do
        collection:check_store(now_tick)
    end
end

--清理超时的记录
function CacheMgr:on_minute()
    local now_tick = quanta.now
    for _, collection in pairs(self.collections) do
        collection:check_expired(now_tick)
    end
end

function CacheMgr:check_doc(coll_name, primary_id, quanta_id)
    local collection = self.collections[coll_name]
    if not collection then
        return CNOT_EXIST
    end
    local doc = collection:get_doc(primary_id)
    if not doc then
        return DNOT_EXIST
    end
    local lock_node_id = doc:get_lock_node_id()
    if lock_node_id ~= 0 and lock_node_id ~= quanta_id then
        log_err("[CacheMgr][check_doc] check_doc failed! coll_name=%s, lock_node_id=%s, quanta_id=%s", coll_name, lock_node_id, quanta_id)
        return LOCK_FAILD
    end
    return SUCCESS, doc, collection
end

function CacheMgr:rpc_cache_load(quanta_id,  primary_id, coll_name, primary_key, group)
    local collection = self.collections[coll_name]
    if not collection then
        collection = Collection(coll_name, primary_key, group)
        self.collections[coll_name] = collection
    end
    local code, doc = collection:load(primary_id)
    if qfailed(code) then
        log_err("[CacheMgr][rpc_cache_load] doc not find! coll_name=%s, primary=%s", coll_name, primary_id)
        return code
    end
    doc:set_lock_node_id(quanta_id)
    log_info("[CacheMgr][rpc_cache_load] coll_name=%s, primary=%s", coll_name, primary_id)
    return code, doc:get_datas()
end

--更新缓存kv
function CacheMgr:rpc_cache_update_field(quanta_id, primary_id, coll_name, field, field_data, flush)
    local ccode, doc, collection = self:check_doc(coll_name, primary_id, quanta_id)
    if qfailed(ccode) then
        log_err("[CacheMgr][rpc_cache_update_field] check_doc failed! coll_name=%s, primary=%s, field=%s", coll_name, primary_id, field)
        return ccode
    end
    collection:update_field(primary_id, doc, field, field_data, flush)
    return SUCCESS
end

--更新缓存kv
function CacheMgr:rpc_cache_remove_field(quanta_id, primary_id, coll_name, field, flush)
    local ccode, doc, collection = self:check_doc(coll_name, primary_id, quanta_id)
    if qfailed(ccode) then
        log_err("[CacheMgr][rpc_cache_remove_field] check_doc failed! coll_name=%s, primary=%s, field=%s", coll_name, primary_id, field)
        return ccode
    end
    collection:remove_field(primary_id, doc, field, flush)
    return SUCCESS
end

--删除缓存，通常由运维指令执行
function CacheMgr:rpc_cache_delete(quanta_id, primary_id, coll_name)
    local ccode, _, collection = self:check_doc(coll_name, primary_id, quanta_id)
    if qfailed(ccode) then
        log_err("[CacheMgr][rpc_cache_delete] check_doc failed! coll_name=%s, primary=%s", coll_name, primary_id)
        return ccode
    end
    local code = collection:delete(primary_id)
    if qfailed(code) then
        log_err("[CacheMgr][rpc_cache_delete] delete failed! coll_name=%s, primary=%s", coll_name, primary_id)
        return DELETE_FAILD
    end
    return SUCCESS
end

--缓存落地
function CacheMgr:rpc_cache_flush(primary_id, group)
    for coll_name, collection in pairs(self.collections) do
        if group == collection:get_group() then
            if qfailed(collection:flush(primary_id)) then
                log_err("[CacheMgr][rpc_cache_flush] flush %s failed! primary=%s", coll_name, primary_id)
            end
        end
    end
    log_info("[CacheMgr][rpc_cache_flush] save success: primary=%s", primary_id)
    return SUCCESS
end

--停服
function CacheMgr:rpc_server_close()
    log_debug("[CacheMgr][rpc_server_close] cache close")
    for _, collection in pairs(self.collections) do
        collection:save_all(true)
    end
    return FRAME_SUCCESS, {msg = "success"}
end

quanta.cache_mgr = CacheMgr()

return CacheMgr
