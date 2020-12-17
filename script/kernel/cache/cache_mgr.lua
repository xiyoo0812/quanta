-- cache_mgr.lua
-- cache_mgr
import("kernel/store/mongo_mgr.lua")
local tunpack       = table.unpack
local tinsert       = table.insert
local log_err       = logger.err
local log_info      = logger.info
local env_colon     = environ.colon
local env_number    = environ.number
local check_failed  = utility.check_failed

local KernCode      = enum("KernCode")
local CacheCode     = enum("CacheCode")
local PeriodTime    = enum("PeriodTime")
local SUCCESS       = KernCode.SUCCESS

local event_mgr     = quanta.event_mgr
local timer_mgr     = quanta.timer_mgr
local config_mgr    = quanta.config_mgr

local CacheObj      = import("kernel/cache/cache_obj.lua")
local WheelMap      = import("kernel/basic/wheel_map.lua")
local obj_table     = config_mgr:init_table("cache_obj", "cache_table")
local row_table     = config_mgr:init_table("cache_row", "cache_table")

local CacheMgr = singleton()
local prop = property(CacheMgr)
prop:accessor("cache_hash", nil)        -- 分区内的哈希特征值
prop:accessor("cache_id", nil)          -- 缓存id，默认数据库id与分区id一致
prop:accessor("cache_enable", true)     -- 缓存开关
prop:accessor("cache_confs", {})        -- cache_confs
prop:accessor("cache_lists", {})        -- cache_lists
prop:accessor("dirty_map", nil)         -- dirty objects
prop:accessor("rebuild_objs", {})       -- rebuild objects

function CacheMgr:__init()
    --初始化cache
    self:setup()
    -- 监听rpc事件
    event_mgr:add_listener(self, "rpc_cache_load")
    event_mgr:add_listener(self, "rpc_cache_update")
    event_mgr:add_listener(self, "rpc_cache_update_key")
    event_mgr:add_listener(self, "rpc_cache_delete")
    event_mgr:add_listener(self, "rpc_cache_flush")
    event_mgr:add_listener(self, "rpc_cache_rebuild")
    event_mgr:add_listener(self, "rpc_load_cache_hash")
    --定时器
    timer_mgr:loop(PeriodTime.SECOND_MS, function(ms)
        self:on_timer_update(ms)
    end)
    timer_mgr:loop(PeriodTime.SECOND_10_MS, function(ms)
        self:on_timer_expire(ms)
    end)
end

function CacheMgr:setup()
    --加载参数
    self.cache_id = env_number("QUANTA_PART_ID")
    self.cache_hash = env_colon("QUANTA_CACHE_HASH")
    log_info("[CacheMgr:setup] load cache config: cache_id=%s,cache_hash=%s", self.cache_id, self.cache_hash)
    --加载配置
    for _, obj_conf in obj_table:iterator() do
        obj_conf.rows = {}
        local cache_name = obj_conf.cache_name
        self.cache_confs[cache_name] = obj_conf
        self.cache_lists[cache_name] = {}
    end
    for _, row_conf in row_table:iterator() do
        local cache_name = row_conf.cache_name
        local obj_conf =  self.cache_confs[cache_name]
        if obj_conf then
            tinsert(obj_conf.rows, row_conf)
        else
            log_err("[CacheMgr:setup] cache row config obj:%s not exist !", cache_name)
        end
    end
    -- 创建WheelMap
    self.dirty_map = WheelMap(10)
end

--获取区服配置
function CacheMgr:rpc_load_cache_hash(quanta_id, service_name)
    local rpc_res = {
        quanta_id   = quanta.id,
        cache_id    = self.cache_id,
        cache_hash  = self.cache_hash,
    }
    return SUCCESS, rpc_res
end

function CacheMgr:on_timer_update()
    --存储脏数据
    local now_tick = quanta.now
    for uuid, obj in self.dirty_map:wheel_iterator() do
        if obj:check_store(now_tick) then
            self.dirty_map:set(uuid, nil)
        end
    end
    --处理重建
    for primary_key, info in pairs(self.rebuild_objs) do
        local quanta_id, cache_list, conf = tunpack(info)
        self:load_cache_impl(quanta_id, cache_list, conf, primary_key)
    end
end

function CacheMgr:on_timer_expire()
    --清理超时的记录
    local now_tick = quanta.now
    for cache_name, obj_list in pairs(self.cache_lists) do
        for primary_key, obj in pairs(obj_list) do
            if obj:expired(now_tick) then
                log_info("[CacheMgr][on_timer_expire] cache(%s)'s data(%s) expired!", cache_name, primary_key)
                obj_list[primary_key] = nil
            end
        end
    end
end

--缓存重建
function CacheMgr:load_cache_impl(quanta_id, cache_list, conf, primary_key)
    local cache_obj = CacheObj(conf, primary_key, self.cache_id)
    cache_obj:set_lock_node_id(quanta_id)
    cache_list[primary_key] = cache_obj
    --开始加载
    local code = cache_obj:load()
    if check_failed(code) then
        cache_list[primary_key] = nil
        return code
    end
    self.rebuild_objs[primary_key] = nil
    return SUCCESS, cache_obj
end

--缓存重建
function CacheMgr:rpc_cache_rebuild(quanta_id, req_data)
    local cache_name, primary_keys = tunpack(req_data)
    local cache_list = self.cache_lists[cache_name]
    if not cache_list then
        log_info("[CacheMgr][rpc_cache_rebuild] cache list not find! cache=%s,primary=%s", cache_name, primary_keys)
        return CacheCode.CACHE_NOT_SUPPERT
    end
    local conf = self.cache_confs[cache_name]
    for _, primary_key in pairs(primary_keys) do
        local cache_obj = cache_list[primary_key]
        if not cache_obj then
            local code = self:load_cache_impl(quanta_id, cache_list, conf, primary_key)
            if check_failed(code) then
                self.rebuild_objs[primary_key] = {quanta_id, cache_list, conf}
            end
        end
    end
    return SUCCESS
end

--加载缓存
function CacheMgr:rpc_cache_load(quanta_id, req_data)
    local cache_name, primary_key = tunpack(req_data)
    local cache_list = self.cache_lists[cache_name]
    if not cache_list then
        log_err("[CacheMgr][rpc_cache_load] cache list not find! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_NOT_SUPPERT
    end
    local cache_obj = cache_list[primary_key]
    if not cache_obj then
        local conf = self.cache_confs[cache_name]
        local code, cobj = self:load_cache_impl(quanta_id, cache_list, conf, primary_key)
        if check_failed(code) then
            return code
        end
        cache_obj = cobj
    else
        if cache_obj:is_holding() then
            log_err("[CacheMgr][rpc_cache_flush] cache node not match! cache_name=%s,primary=%s", cache_name, primary_key)
            return CacheCode.CACHE_IS_HOLDING
        end
        cache_obj:set_flush(false)
        cache_obj:set_lock_node_id(quanta_id)
    end
    log_info("[CacheMgr][rpc_cache_load] cache=%s,primary=%s", cache_name, primary_key)
    return SUCCESS, cache_obj:pack()
end

--更新缓存
function CacheMgr:rpc_cache_update(quanta_id, req_data)
    local cache_name, primary_key, table_name, table_data, flush = tunpack(req_data)
    local cache_list = self.cache_lists[cache_name]
    if not cache_list then
        log_err("[CacheMgr][rpc_cache_update] cache list not find! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_NOT_SUPPERT
    end
    local cache_obj = cache_list[primary_key]
    if not cache_obj then
        log_err("[CacheMgr][rpc_cache_update] cache obj not find! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_PKEY_IS_NOT_EXIST
    end
    if quanta_id ~= cache_obj:get_lock_node_id() then
        log_err("[CacheMgr][rpc_cache_update] cache node not match! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_KEY_LOCK_FAILD
    end
    if cache_obj:is_holding() then
        log_err("[CacheMgr][rpc_cache_update] cache is holding! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_IS_HOLDING
    end
    local code = cache_obj:update(table_name, table_data, flush)
    if cache_obj:is_dirty() then
        self.dirty_map:set(cache_obj:get_uuid(), cache_obj)
    end
    return code
end

--更新缓存kv
function CacheMgr:rpc_cache_update_key(quanta_id, req_data)
    local cache_name, primary_key, table_name, table_key, table_value, flush = tunpack(req_data)
    local cache_list = self.cache_lists[cache_name]
    if not cache_list then
        log_err("[CacheMgr][rpc_cache_update_key] cache list not find! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_NOT_SUPPERT
    end
    local cache_obj = cache_list[primary_key]
    if not cache_obj then
        log_err("[CacheMgr][rpc_cache_update_key] cache obj not find! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_PKEY_IS_NOT_EXIST
    end
    if quanta_id ~= cache_obj:get_lock_node_id() then
        log_err("[CacheMgr][rpc_cache_flush] cache node not match! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_KEY_LOCK_FAILD
    end
    if cache_obj:is_holding() then
        log_err("[CacheMgr][rpc_cache_delete] cache is holding! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_IS_HOLDING
    end
    local code = cache_obj:update_key(table_name, table_key, table_value, flush)
    if cache_obj:is_dirty() then
        self.dirty_map:set(cache_obj:get_uuid(), cache_obj)
    end
    return code
end

--删除缓存，通常由运维指令执行
function CacheMgr:rpc_cache_delete(quanta_id, req_data)
    local cache_name, primary_key = tunpack(req_data)
    local cache_list = self.cache_lists[cache_name]
    if not cache_list then
        log_err("[CacheMgr][rpc_cache_delete] cache list not find! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_NOT_SUPPERT
    end
    local cache_obj = cache_list[primary_key]
    if not cache_obj then
        log_err("[CacheMgr][rpc_cache_delete] cache obj not find! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_PKEY_IS_NOT_EXIST
    end
    if cache_obj:is_holding() then
        log_err("[CacheMgr][rpc_cache_delete] cache is holding! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_IS_HOLDING
    end
    cache_obj:set_holding(true)
    if cache_obj:save() then
        cache_list[primary_key] = nil
        self.dirty_map:set(cache_obj:get_uuid(), nil)
        log_info("[CacheMgr][rpc_cache_delete] cache=%s,primary=%s", cache_name, primary_key)
        return SUCCESS
    end
    cache_obj:set_holding(false)
    log_err("[CacheMgr][rpc_cache_delete] save failed: cache=%s,primary=%s", cache_name, primary_key)
    return CacheCode.CACHE_DELETE_SAVE_FAILD
end

--缓存落地
function CacheMgr:rpc_cache_flush(quanta_id, req_data)
    local cache_name, primary_key = tunpack(req_data)
    local cache_list = self.cache_lists[cache_name]
    if not cache_list then
        log_err("[CacheMgr][rpc_cache_flush] cache list not find! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_NOT_SUPPERT
    end
    local cache_obj = cache_list[primary_key]
    if not cache_obj then
        log_err("[CacheMgr][rpc_cache_flush] cache obj not find! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_PKEY_IS_NOT_EXIST
    end
    if quanta_id ~= cache_obj:get_lock_node_id() then
        log_err("[CacheMgr][rpc_cache_flush] cache node not match! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_KEY_LOCK_FAILD
    end
    if cache_obj:is_holding() then
        log_err("[CacheMgr][rpc_cache_flush] cache is holding! cache_name=%s,primary=%s", cache_name, primary_key)
        return CacheCode.CACHE_IS_HOLDING
    end
    if cache_obj:save() then
        cache_obj:set_flush(true)
        self.dirty_map:set(cache_obj:get_uuid(), nil)
        log_info("[CacheMgr][rpc_cache_flush] cache=%s,primary=%s", cache_name, primary_key)
        return SUCCESS
    end
    log_err("[CacheMgr][rpc_cache_flush] save failed: cache=%s,primary=%s", cache_name, primary_key)
    return CacheCode.CACHE_DELETE_SAVE_FAILD
end

quanta.cache_mgr = CacheMgr()

return CacheMgr
