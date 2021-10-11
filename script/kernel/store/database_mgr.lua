--database_mgr.lua
local log_info      = logger.info
local log_debug     = logger.debug
local env_get       = environ.get

local event_mgr     = quanta.get("event_mgr")
local DBGroup       = enum("DBGroup")
local KernCode      = enum("KernCode")
local DB_NOTINIT    = KernCode.DB_NOTINIT

local DatabaseMgr = singleton()
local prop = property(DatabaseMgr)
prop:accessor("database_mgrs", {})      -- database mgrs

function DatabaseMgr:__init()
    self:setup()
end

function DatabaseMgr:setup()
    --初始化dbmgr
    local db_driver = env_get("QUANTA_DB_DRIVER")
    for group = DBGroup.AREA, DBGroup.HASH do
        if db_driver == "mongo" then
            log_info("[DatabaseMgr][setup]: general mongo_mgr group=%s", group)
            local MongoMgr = import("kernel/store/mongo_mgr.lua")
            self.database_mgrs[group] = MongoMgr(group)
            -- 注册事件
            event_mgr:add_listener(self, "mongo_find")
            event_mgr:add_listener(self, "mongo_count")
            event_mgr:add_listener(self, "mongo_insert")
            event_mgr:add_listener(self, "mongo_delete")
            event_mgr:add_listener(self, "mongo_update")
            event_mgr:add_listener(self, "mongo_collect")
            event_mgr:add_listener(self, "mongo_execute")
            event_mgr:add_listener(self, "mongo_find_one")
            event_mgr:add_listener(self, "mongo_drop_indexes")
            event_mgr:add_listener(self, "mongo_create_indexes")
        elseif db_driver == "mysql" then
            log_info("[DatabaseMgr][setup]: general mysql_mgr group=%s", group)
            local MysqlMgr = import("kernel/store/mysql_mgr.lua")
            self.database_mgrs[group] = MysqlMgr(group)
            -- 注册事件
            event_mgr:add_listener(self, "mysql_execute")
        elseif db_driver == "redis" then
            log_info("[DatabaseMgr][setup]: general redis_mgr group=%s", group)
            local RedisMgr = import("kernel/store/redis_mgr.lua")
            self.database_mgrs[group] = RedisMgr(group)
            -- 注册事件
            event_mgr:add_listener(self, "redis_execute")
        end
    end
end

--返回数据库管理器
function DatabaseMgr:get_databese_mgr(db_group)
    return self.database_mgrs[db_group]
end

function DatabaseMgr:mongo_find(db_group, index, coll_name, selector, fields, sortor, limit)
    log_debug("[DatabaseMgr][mongo_find]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:find(index, coll_name, selector, fields, sortor, limit)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:mongo_collect(db_group, coll_name, selector, fields, sortor, limit)
    log_debug("[DatabaseMgr][mongo_collect]: db_group=%s,coll_name=%s", db_group, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:collect(coll_name, selector, fields, sortor, limit)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:mongo_find_one(db_group, index, coll_name, selector, fields)
    log_debug("[DatabaseMgr][mongo_find_one]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:find_one(index, coll_name, selector, fields)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:mongo_insert(db_group, index, coll_name, obj)
    log_debug("[DatabaseMgr][mongo_insert]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:insert(index, coll_name, obj)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:mongo_update(db_group, index, coll_name, obj, selector, upsert, multi)
    log_debug("[DatabaseMgr][mongo_update]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:update(index, coll_name, obj, selector, upsert, multi)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:mongo_delete(db_group, index, coll_name, selector, onlyone)
    log_debug("[DatabaseMgr][mongo_delete]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:delete(index, coll_name, selector, onlyone)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:mongo_count(db_group, index, coll_name, selector, limit, skip)
    log_debug("[DatabaseMgr][mongo_count]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:count(index, coll_name, selector, limit, skip)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:mongo_create_indexes(db_group, index, coll_name, indexes)
    log_debug("[DatabaseMgr][mongo_create_indexes]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:create_indexes(index, coll_name, indexes)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:mongo_drop_indexes(db_group, index, coll_name, index_name)
    log_debug("[DatabaseMgr][mongo_drop_indexes]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:drop_indexes(index, coll_name, index_name)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:mongo_execute(db_group, index, cmd, ...)
    log_debug("[DatabaseMgr][mongo_execute]: db_group=%s,index=%s,cmd=%s", db_group, index, cmd)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:execute(index, cmd, ...)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:mysql_execute(db_group, index, sql)
    log_debug("[DatabaseMgr][mysql_execute]: db_group=%s,index=%s,sql=%s", db_group, index, sql)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:execute(index, sql)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:redis_execute(db_group, index, cmd, ...)
    log_debug("[DatabaseMgr][redis_execute]: db_group=%s,index=%s,cmd=%s", db_group, index, cmd)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:execute(index, cmd, ...)
    end
    return DB_NOTINIT, "db mgr not init"
end

quanta.database_mgr = DatabaseMgr()

return DatabaseMgr
