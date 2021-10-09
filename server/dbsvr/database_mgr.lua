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
    -- 注册事件
    event_mgr:add_listener(self, "find")
    event_mgr:add_listener(self, "insert")
    event_mgr:add_listener(self, "delete")
    event_mgr:add_listener(self, "update")
    event_mgr:add_listener(self, "collect")
    event_mgr:add_listener(self, "find_one")
    event_mgr:add_listener(self, "count")
    event_mgr:add_listener(self, "create_indexes")
    event_mgr:add_listener(self, "drop_indexes")
end

function DatabaseMgr:setup()
    --初始化dbmgr
    local db_driver = env_get("QUANTA_DB_DRIVER")
    for group = DBGroup.AREA, DBGroup.HASH do
        if db_driver == "mongo" then
            log_info("[DatabaseMgr][setup]: general mongo_mgr group=%s", group)
            local MongoMgr = import("kernel/store/mongo_mgr.lua")
            self.database_mgrs[group] = MongoMgr(group)
        elseif db_driver == "mysql" then
            log_info("[DatabaseMgr][setup]: general mysql_mgr group=%s", group)
            local MysqlMgr = import("kernel/store/mysql_mgr.lua")
            self.database_mgrs[group] = MysqlMgr(group)
        end
    end
end

--返回数据库管理器
function DatabaseMgr:get_databese_mgr(db_group)
    return self.database_mgrs[db_group]
end

function DatabaseMgr:find(db_group, index, coll_name, selector, fields, sortor, limit)
    log_debug("[DatabaseMgr][find]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:find(index, coll_name, selector, fields, sortor, limit)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:collect(db_group, coll_name, selector, fields, sortor, limit)
    log_debug("[DatabaseMgr][collect]: db_group=%s,coll_name=%s", db_group, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:collect(coll_name, selector, fields, sortor, limit)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:find_one(db_group, index, coll_name, selector, fields)
    log_debug("[DatabaseMgr][find_one]: db_group=%s,index=%s,coll_name=%s", db_group, index, coll_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:find_one(index, coll_name, selector, fields)
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

function DatabaseMgr:create_indexes(db_group, index, coll_name, indexes)
    log_debug("[DatabaseMgr][create_indexes]: db_group=%s,coll_name=%s,indexes=%s", db_group, coll_name, indexes)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:create_indexes(index, coll_name, indexes)
    end
    return DB_NOTINIT, "db mgr not init"
end

function DatabaseMgr:drop_indexes(db_group, coll_name, index_name)
    log_debug("[DatabaseMgr][drop_indexes]: db_group=%s,coll_name=%s,index_name=%s", db_group, coll_name, index_name)
    local database_mgr = self:get_databese_mgr(db_group)
    if database_mgr then
        return database_mgr:drop_indexes(index, coll_name, index_name)
    end
    return DB_NOTINIT, "db mgr not init"
end

quanta.database_mgr = DatabaseMgr()

return DatabaseMgr
