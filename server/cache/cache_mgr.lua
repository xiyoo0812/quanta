-- cache_mgr.lua
import("store/mongo_mgr.lua")
import("store/redis_mgr.lua")

local log_err       = logger.err
local log_debug     = logger.debug
local tsort         = table.sort
local tinsert       = table.insert
local ssplit        = qstring.split
local qfailed       = quanta.failed
local convint       = qmath.conv_integer
local makechan      = quanta.make_channel

local event_mgr     = quanta.get("event_mgr")
local redis_mgr     = quanta.get("redis_mgr")
local mongo_mgr     = quanta.get("mongo_mgr")
local router_mgr    = quanta.get("router_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local config_mgr    = quanta.get("config_mgr")
local update_mgr    = quanta.get("update_mgr")

local cache_db      = config_mgr:init_table("cache", "sheet")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local DB_LOAD_ERR   = quanta.enum("CacheCode", "CACHE_DB_LOAD_ERR")
local DELETE_FAILD  = quanta.enum("CacheCode", "CACHE_DELETE_FAILD")

local ROUTER_COL    = "player"
local CACHE_MAX     = environ.number("QUANTA_DB_CACHE_MAX")
local CACHE_FLUSH   = environ.number("QUANTA_DB_CACHE_FLUSH")

local QueueLRU      = import("container/queue_lru.lua")

local CacheMgr = singleton()
local prop = property(CacheMgr)
prop:reader("caches", {})           -- caches
prop:reader("groups", {})           -- groups
prop:reader("kindexs", {})          -- kindexs
prop:reader("collections", {})      -- collections
prop:reader("del_documents", {})    -- del documents
prop:reader("save_documents", {})   -- save documents
prop:reader("counter", nil)

function CacheMgr:__init()
    -- 监听rpc事件
    event_mgr:add_listener(self, "rpc_cache_load")
    event_mgr:add_listener(self, "rpc_cache_copy")
    event_mgr:add_listener(self, "rpc_cache_flush")
    event_mgr:add_listener(self, "rpc_cache_update")
    event_mgr:add_listener(self, "rpc_cache_delete")
    event_mgr:add_listener(self, "rpc_cache_signed")
    event_mgr:add_listener(self, "rpc_router_update")
    -- 事件监听
    event_mgr:add_listener(self, "on_cache_ready")
    -- 事件hook
    event_mgr:register_hook(self, "rpc_cache_load", "on_cache_hook")
    event_mgr:register_hook(self, "rpc_cache_copy", "on_cache_hook")
    event_mgr:register_hook(self, "rpc_cache_update", "on_cache_hook")
    event_mgr:register_hook(self, "rpc_cache_delete", "on_cache_hook")
    event_mgr:register_hook(self, "rpc_cache_signed", "on_cache_hook")
    event_mgr:register_hook(self, "rpc_router_update", "on_cache_hook")
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
            local sgroup = {}
            for _, sconf in pairs(cache_db:find_group(group_name)) do
                tinsert(sgroup, sconf)
            end
            tsort(sgroup, function(a, b) return a.id < b.id end)
            self.groups[group_name] = sgroup
        end
    end
end

function CacheMgr:build_fields(field)
    local fields = self.kindexs[field]
    if not fields then
        fields = ssplit(field, ".")
        for i, sfield in ipairs(fields) do
            fields[i] = convint(sfield)
        end
        self.kindexs[field] = fields
    end
    return fields, #fields
end

--RPC hook
function CacheMgr:on_cache_hook(rpc, hook, primary_id)
    hook:register(function()
        thread_mgr:unlock(primary_id)
    end)
    thread_mgr:lock(primary_id, true)
end

--清理缓存
function CacheMgr:on_cache_ready(group_name, primary_id)
    log_debug("[CacheMgr][on_cache_ready] group_name={}, primary={}", group_name, primary_id)
    local groups = self.caches[group_name]
    if groups then
        groups:del(primary_id)
    end
end

--需要更新的表
function CacheMgr:save_doc(document)
    self.save_documents[document] = true
end

--更新数据
function CacheMgr:on_frame()
    if not redis_mgr:available() then
        return
    end
    if not mongo_mgr:available() then
        return
    end
    --保存数据
    local save_channel = makechan("save cache")
    for doc in pairs(self.save_documents) do
        save_channel:push(function()
            local ok, code = doc:update()
            if qfailed(code, ok) then
                self.save_documents[doc] = true
                return false
            end
            return true, code
        end)
        self.save_documents[doc] = nil
        if save_channel:isfull(CACHE_FLUSH) then
            break
        end
    end
    --删除数据
    local del_channel = makechan("save cache")
    for doc in pairs(self.del_documents) do
        del_channel:push(function()
            local ok, code = doc:destory()
            if qfailed(code, ok) then
                self.del_documents[doc] = true
                return false
            end
            return true, code
        end)
        self.del_documents[doc] = nil
        if del_channel:isfull(CACHE_FLUSH) then
            break
        end
    end
    save_channel:execute(true)
    del_channel:execute(true)
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

--清理文档
function CacheMgr:clear_document(coll_name, primary_id)
    local group_name = self.collections[coll_name]
    local groups = self.caches[group_name]
    local group = groups:get(primary_id)
    if group then
        group:clear()
        groups[primary_id] = nil
    end
end

--加载DB组
function CacheMgr:load_group(coll_name, primary_id)
    --准备信息
    local group_name = self.collections[coll_name]
    local gconfs = self.groups[group_name]
    --拉取数据
    local Group = import("cache/group.lua")
    local group = Group(group_name)
    if not group:load(primary_id, gconfs) then
        log_err("[CacheMgr][load_group] group load failed! coll_name={}, primary={}", group_name, primary_id)
        return DB_LOAD_ERR
    end
    local groups = self.caches[group_name]
    groups:set(primary_id, group)
    router_mgr:call_cache_all("on_cache_ready", group_name, primary_id)
    return SUCCESS, group
end

--加载文档
function CacheMgr:load_document(coll_name, primary_id)
    local doc = self:find_document(coll_name, primary_id)
    if not doc then
        local code, group = self:load_group(coll_name, primary_id)
        if qfailed(code) then
            return code
        end
        return SUCCESS, group:get_doc(coll_name), false
    else
        return SUCCESS, doc, true
    end
end

function CacheMgr:rpc_router_update(primary_id, router_id, serv_name, serv_id)
    log_debug("[CacheMgr][rpc_router_update] router_id={}, primary={}, service: {}-{}", router_id, primary_id, serv_name, serv_id)
    local ccode, doc = self:load_document(ROUTER_COL, primary_id)
    if qfailed(ccode) then
        log_err("[CacheMgr][rpc_router_update] load_document failed! primary={}", primary_id)
        return ccode
    end
    if serv_name and serv_id then
        local routers = doc:get("routers") or {}
        local old_rid = routers.router
        if old_rid and old_rid ~= router_id then
            local router = router_mgr:get_router(old_rid)
            if router then
                router:send("rpc_router_clean", primary_id)
            end
        end
        if router_id == 0 then
            doc:update_commit({{}, "routers", {}, true})
        else
            local old_svr_id = routers[serv_name]
            doc:update_commit({{}, "routers", {router = router_id, [serv_name] = serv_id }})
            --通知节点改变
            if old_svr_id and old_svr_id > 0 and old_svr_id ~= serv_id then
                router_mgr:send_target(old_svr_id, "rpc_service_svr_changed", primary_id)
            end
        end
    end
    return ccode, doc:get("routers") or {}
end

function CacheMgr:rpc_cache_load(primary_id, coll_name)
    self.counter:count_increase()
    local code, doc = self:load_document(coll_name, primary_id)
    if qfailed(code) then
        log_err("[CacheMgr][rpc_cache_load] load_document failed! coll_name={}, primary={}", coll_name, primary_id)
        return code
    end
    log_debug("[CacheMgr][rpc_cache_load] coll_name={}, primary={}, {}", coll_name, primary_id, doc:load_wholes())
    return code, doc:load_wholes()
end

--更新缓存
function CacheMgr:rpc_cache_flush(primary_id, coll_name, wholes)
    local ccode, doc = self:load_document(coll_name, primary_id)
    if qfailed(ccode) then
        log_err("[CacheMgr][rpc_cache_flush] load_document failed! coll_name={}, primary={}", coll_name, primary_id)
        return ccode
    end
    log_debug("[CacheMgr][rpc_cache_flush] coll_name={}, primary={}, wholes:{}", coll_name, primary_id, wholes)
    doc:update_wholes(wholes)
    return SUCCESS
end

--更新缓存
function CacheMgr:rpc_cache_update(primary_id, coll_name, commits)
    local ccode, doc = self:load_document(coll_name, primary_id)
    if qfailed(ccode) then
        log_err("[CacheMgr][rpc_cache_update] load_document failed! coll_name={}, primary={}", coll_name, primary_id)
        return ccode
    end
    log_debug("[CacheMgr][rpc_cache_update] coll_name={}, primary={}, commits:{}", coll_name, primary_id, commits)
    doc:update_commits(commits)
    return SUCCESS
end

--删除缓存，通常由运维指令执行
function CacheMgr:rpc_cache_delete(primary_id, coll_name)
    local ccode, doc = self:load_document(coll_name, primary_id)
    if qfailed(ccode) then
        log_err("[CacheMgr][rpc_cache_delete] load_document failed! coll_name={}, primary={}", coll_name, primary_id)
        return ccode
    end
    local ok, code = doc:destory()
    if qfailed(code, ok) then
        self.del_documents[doc] = true
        log_err("[CacheMgr][rpc_cache_delete] delete failed! coll_name={}, primary={}", coll_name, primary_id)
        return DELETE_FAILD
    end
    log_debug("[CacheMgr][rpc_cache_delete] coll_name={}, primary={}", coll_name, primary_id)
    return SUCCESS
end

--复制缓存
function CacheMgr:rpc_cache_copy(to_id, src_id, coll_name)
    log_debug("[CacheMgr][rpc_cache_copy] coll_name={}, src_id={}, to_id={}", coll_name, src_id, to_id)
    local src_code, src_doc, from_mem = self:load_document(coll_name, src_id)
    if qfailed(src_code) then
        log_err("[CacheMgr][rpc_cache_copy] load_document failed! coll_name={}, src_id={}", coll_name, src_id)
        return src_code
    end
    --原表是否为空
    if not next(src_doc:get_wholes()) then
        if not from_mem then
            self:clear_document(coll_name, src_id)
        end
        return SUCCESS
    end
    local to_code, doc = self:load_document(coll_name, to_id)
    if qfailed(to_code) then
        log_err("[CacheMgr][rpc_cache_copy] load_document failed! coll_name={}, to_id={}", coll_name, to_id)
        if not from_mem then
            self:clear_document(coll_name, src_id)
        end
        return to_code
    end
    doc:copy(src_doc:get_wholes())
    if not from_mem then
        self:clear_document(coll_name, src_id)
    end
    return SUCCESS
end

--标记注销
function CacheMgr:rpc_cache_signed(primary_id, coll_name)
    local field = "del_time"
    local field_data = quanta.now
    local ccode, doc = self:load_document(coll_name, primary_id)
    if qfailed(ccode) then
        log_err("[CacheMgr][rpc_cache_signed] load_document failed! coll_name={}, primary={}, field={}", coll_name, primary_id, field)
        return ccode
    end
    log_debug("[CacheMgr][rpc_cache_signed] coll_name={}, primary={}, field={}, data:{}", coll_name, primary_id, field, field_data)
    doc:update_field(field, field_data)
    --强制落库
    doc:update()
end

quanta.cache_mgr = CacheMgr()

return CacheMgr
