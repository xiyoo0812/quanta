-- cache_mgr.lua
import("store/mongo_mgr.lua")
import("store/redis_mgr.lua")

local log_err       = logger.err
local log_debug     = logger.debug
local sformat       = string.format
local qfailed       = quanta.failed
local makechan      = quanta.make_channel

local event_mgr     = quanta.get("event_mgr")
local redis_mgr     = quanta.get("redis_mgr")
local router_mgr    = quanta.get("router_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local config_mgr    = quanta.get("config_mgr")
local update_mgr    = quanta.get("update_mgr")

local cache_db      = config_mgr:init_table("cache", "sheet")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local DB_LOAD_ERR   = quanta.enum("CacheCode", "CACHE_DB_LOAD_ERR")
local DELETE_FAILD  = quanta.enum("CacheCode", "CACHE_DELETE_FAILD")

local NAMESPACE     = environ.get("QUANTA_NAMESPACE")
local MAIN_DBID     = environ.number("QUANTA_DB_MAIN_ID")
local CACHE_MAX     = environ.number("QUANTA_DB_CACHE_MAX")
local CACHE_FLUSH   = environ.number("QUANTA_DB_CACHE_FLUSH")

local Group         = import("cache/group.lua")
local QueueLRU      = import("container/queue_lru.lua")

local CacheMgr = singleton()
local prop = property(CacheMgr)
prop:reader("caches", {})           -- caches
prop:reader("groups", {})           -- groups
prop:reader("mlocks", {})           -- 内存锁
prop:reader("collections", {})      -- collections
prop:reader("del_documents", {})    -- del documents
prop:reader("save_documents", {})   -- save documents
prop:reader("counter", nil)

function CacheMgr:__init()
    -- 监听rpc事件
    event_mgr:add_listener(self, "rpc_cache_load")
    event_mgr:add_listener(self, "rpc_cache_delete")
    event_mgr:add_listener(self, "rpc_cache_update_field")
    event_mgr:add_listener(self, "rpc_cache_remove_field")
    -- 事件监听
    event_mgr:add_listener(self, "on_cache_load")
    event_mgr:add_listener(self, "on_document_del")
    event_mgr:add_listener(self, "on_document_save")
    --counter
    self.counter = quanta.make_sampling("cache req")
    --定时器
    update_mgr:attach_frame(self)
    --配置和索引
    cache_db:add_group("group")
    for sheet, conf in cache_db:iterator() do
        local group_name = conf.group
        self.collections[sheet] = group_name
        self.caches[group_name] = QueueLRU(CACHE_MAX)
        if not self.groups[group_name] then
            self.groups[group_name] = cache_db:find_group(group_name)
        end
    end
end

--清理缓存
function CacheMgr:on_cache_load(group_name, primary_id)
    log_debug("[CacheMgr][on_cache_load] group_name=%s, primary=%s", group_name, primary_id)
    local groups = self.caches[group_name]
    if groups then
        groups:del(primary_id)
    end
end

--需要更新的表
function CacheMgr:on_document_del(document)
    self.del_documents[document] = true
end

--需要更新的表
function CacheMgr:on_document_save(document)
    self.save_documents[document] = true
end

--更新数据
function CacheMgr:on_frame()
    local channel = makechan()
    --保存数据
    if next(self.save_documents) then
        local count = 0
        for document in pairs(self.save_documents) do
            channel:push(function()
                local ok, code = document:update()
                if qfailed(code, ok) then
                    return false
                end
                self.save_documents[document] = nil
                return true, code
            end)
            count = count + 1
            if count == CACHE_FLUSH then
                break
            end
        end
    end
    if next(self.del_documents) then
        --删除数据
        local count = 0
        for document in pairs(self.del_documents) do
            channel:push(function()
                local ok, code = document:destory()
                if qfailed(code, ok) then
                    return false
                end
                self.del_documents[document] = nil
                return true, code
            end)
            count = count + 1
            if count == CACHE_FLUSH then
                break
            end
        end
    end
    channel:execute("flush cache")
end

--检查锁
function CacheMgr:check_lock(primary_id)
    local sname = quanta.name
    local lock_key = sformat("CACHE:%s:lock:%s", NAMESPACE, primary_id)
    local code, old_name = redis_mgr:execute(MAIN_DBID, primary_id, "GETSET", lock_key, sname)
    if qfailed(code) then
        log_err("[CacheMgr][check_lock] GETSET failed! code=%s, old_id=%s", code, old_name)
        return false
    end
    return sname == old_name
end

--查找文档
function CacheMgr:find_document(coll_name, primary_id)
    local group_name = self.collections[coll_name]
    local groups = self.caches[group_name]
    local group = groups:get(primary_id)
    if group then
        return group:get_doc(coll_name)
    end
end

--加载DB组
function CacheMgr:load_group(coll_name, primary_id)
    --准备信息
    local group_name = self.collections[coll_name]
    local gconfs = self.groups[group_name]
    --拉取数据
    local group = Group(group_name)
    if not group:load(primary_id, gconfs) then
        log_err("[CacheMgr][load_group] group load failed! coll_name=%s, primary=%s", group_name, primary_id)
        return DB_LOAD_ERR
    end
    local groups = self.caches[group_name]
    groups:set(primary_id, group)
    router_mgr:call_cache_all("on_cache_load", group_name, primary_id)
    return SUCCESS, group
end

--加载文档
function CacheMgr:load_document(coll_name, primary_id)
    local _<close> = thread_mgr:lock(primary_id, true)
    local legal = self:check_lock(primary_id)
    local doc = self:find_document(coll_name, primary_id)
    if not doc or not legal then
        local code, group = self:load_group(coll_name, primary_id)
        if qfailed(code) then
            return code
        end
        return SUCCESS, group:get_doc(coll_name)
    end
    return SUCCESS, doc
end

function CacheMgr:rpc_cache_load(primary_id, coll_name)
    self.counter:count_increase()
    local code, doc = self:load_document(coll_name, primary_id)
    if qfailed(code) then
        log_err("[CacheMgr][rpc_cache_load] load_document failed! coll_name=%s, primary=%s", coll_name, primary_id)
        return code
    end
    log_debug("[CacheMgr][rpc_cache_load] coll_name=%s, primary=%s", coll_name, primary_id)
    return code, doc:get_datas()
end

--更新缓存kv
function CacheMgr:rpc_cache_update_field(primary_id, coll_name, field, field_data)
    local ccode, doc = self:load_document(coll_name, primary_id)
    if qfailed(ccode) then
        log_err("[CacheMgr][rpc_cache_update_field] load_document failed! coll_name=%s, primary=%s, field=%s", coll_name, primary_id, field)
        return ccode
    end
    log_debug("[CacheMgr][rpc_cache_update_field] coll_name=%s, primary=%s, field=%s, data:%s", coll_name, primary_id, field, field_data)
    doc:update_field(field, field_data)
    return SUCCESS
end

--更新缓存kv
function CacheMgr:rpc_cache_remove_field(primary_id, coll_name, field)
    local ccode, doc = self:load_document(coll_name, primary_id)
    if qfailed(ccode) then
        log_err("[CacheMgr][rpc_cache_remove_field] load_document failed! coll_name=%s, primary=%s, field=%s", coll_name, primary_id, field)
        return ccode
    end
    doc:remove_field(field)
    log_debug("[CacheMgr][rpc_cache_remove_field] coll_name=%s, primary=%s, field=%s", coll_name, primary_id, field)
    return SUCCESS
end

--删除缓存，通常由运维指令执行
function CacheMgr:rpc_cache_delete(primary_id, coll_name)
    local ccode, doc = self:load_document(coll_name, primary_id)
    if qfailed(ccode) then
        log_err("[CacheMgr][rpc_cache_delete] load_document failed! coll_name=%s, primary=%s", coll_name, primary_id)
        return ccode
    end
    local ok, code = doc:destory()
    if qfailed(code, ok) then
        self.del_documents[doc] = true
        log_err("[CacheMgr][rpc_cache_delete] delete failed! coll_name=%s, primary=%s", coll_name, primary_id)
        return DELETE_FAILD
    end
    log_debug("[CacheMgr][rpc_cache_delete] coll_name=%s, primary=%s", coll_name, primary_id)
    return SUCCESS
end

quanta.cache_mgr = CacheMgr()

return CacheMgr
