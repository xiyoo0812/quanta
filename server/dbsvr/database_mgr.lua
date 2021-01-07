--database_mgr.lua
local log_info      = logger.info
local log_debug     = logger.debug
local env_get       = environ.get

local event_mgr     = quanta.event_mgr

local DBGroup       = enum("DBGroup")
local KernCode      = enum("KernCode")
local DB_NOTINIT    = KernCode.DB_NOTINIT

local DatabaseMgr = singleton()
local prop = property(DatabaseMgr)
prop:accessor("database_mgrs", {})      -- database mgrs

function DatabaseMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "find")
    event_mgr:add_listener(self, "insert")
    event_mgr:add_listener(self, "delete")
    event_mgr:add_listener(self, "update")
    event_mgr:add_listener(self, "find_one")
    event_mgr:add_listener(self, "count")
end

function DatabaseMgr:setup()
    --初始化dbmgr
    local cache_driver = env_get("QUANTA_DB_DRIVER")
    for group = DBGroup.AREA, DBGroup.HASH do
        if cache_driver == "mongo" then
            log_info("[DatabaseMgr][setup]: general mongo_mgr group=%s", group)
            local MongoMgr = import("kernel/store/mongo_mgr.lua")
            self.database_mgrs[group] = MongoMgr(group)
        end
    end
end

--返回数据库管理器
function DatabaseMgr:get_databese_mgr(db_group)
    return self.database_mgrs[db_group]
end

function DatabaseMgr:find(db_group, index, coll_name, query, selector, limit, query_num)
    log_debug("[DatabaseMgr][find]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:find(index, coll_name, query, selector, limit, query_num)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:find_one(db_group, index, coll_name, query, selector)
    log_debug("[DatabaseMgr][find_one]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:find_one(index, coll_name, query, selector)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:insert(db_group, index, coll_name, obj)
    log_debug("[DatabaseMgr][insert]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:insert(index, coll_name, obj)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:update(db_group, index, coll_name, obj, selector, upsert, multi)
    log_debug("[DatabaseMgr][update]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:update(index, coll_name, obj, selector, upsert, multi)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:delete(db_group, index, coll_name, selector, onlyone)
    log_debug("[DatabaseMgr][delete]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:delete(index, coll_name, selector, onlyone)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:count(db_group, index, coll_name, selector, limit, skip)
    log_debug("[DatabaseMgr][count]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:count(index, coll_name, selector, limit, skip)
    end
    return DB_NOTINIT, "db mgr not init"
end

quanta.database_mgr = DatabaseMgr()

return DatabaseMgr
