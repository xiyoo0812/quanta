--mongo_mgr.lua
local qget          = quanta.get
local qenum         = quanta.enum

local event_mgr     = qget("event_mgr")
local config_mgr    = qget("config_mgr")

local SUCCESS       = qenum("KernCode", "SUCCESS")
local MONGO_FAILED  = qenum("KernCode", "MONGO_FAILED")

local MongoMgr = singleton()
local prop = property(MongoMgr)
prop:accessor("mongo_dbs", {})      -- mongo_dbs
prop:accessor("default_db", nil)    -- default_db

function MongoMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "mongo_find", "find")
    event_mgr:add_listener(self, "mongo_count", "count")
    event_mgr:add_listener(self, "mongo_insert", "insert")
    event_mgr:add_listener(self, "mongo_delete", "delete")
    event_mgr:add_listener(self, "mongo_update", "update")
    event_mgr:add_listener(self, "mongo_execute", "execute")
    event_mgr:add_listener(self, "mongo_find_one", "find_one")
    event_mgr:add_listener(self, "mongo_drop_indexes", "drop_indexes")
    event_mgr:add_listener(self, "mongo_create_indexes", "create_indexes")
    event_mgr:add_listener(self, "mongo_find_and_modify", "find_and_modify")
end

--初始化
function MongoMgr:setup()
    local MongoDB = import("driver/mongo.lua")
    local database = config_mgr:init_table("database", "db", "driver")
    for _, conf in database:iterator() do
        if conf.driver == "mongo" then
            local mongo_db = MongoDB(conf)
            self.mongo_dbs[conf.db] = mongo_db
            if conf.default then
                self.default_db = mongo_db
            end
        end
    end
end

--查找mongo db
function MongoMgr:get_db(db_name)
    if not db_name or db_name == "default" then
        return self.default_db
    end
    return self.mongo_dbs[db_name]
end

function MongoMgr:find(db_name, coll_name, selector, fields, sortor, limit)
    local mongodb = self:get_db(db_name)
    if mongodb then
        local ok, res_oe = mongodb:find(coll_name, selector, fields, sortor, limit)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:find_one(db_name, coll_name, selector, fields)
    local mongodb = self:get_db(db_name)
    if mongodb then
        local ok, res_oe = mongodb:find_one(coll_name, selector, fields)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:insert(db_name, coll_name, obj)
    local mongodb = self:get_db(db_name)
    if mongodb then
        local ok, res_oe = mongodb:insert(coll_name, obj)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:update(db_name, coll_name, obj, selector, upsert, multi)
    local mongodb = self:get_db(db_name)
    if mongodb then
        local ok, res_oe = mongodb:update(coll_name, obj, selector, upsert, multi)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:delete(db_name, coll_name, selector, onlyone)
    local mongodb = self:get_db(db_name)
    if mongodb then
        local ok, res_oe = mongodb:delete(coll_name, selector, onlyone)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:count(db_name, coll_name, selector, limit, skip)
    local mongodb = self:get_db(db_name)
    if mongodb then
        local ok, res_oe = mongodb:count(coll_name, selector, limit, skip)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:create_indexes(db_name, coll_name, indexes)
    local mongodb = self:get_db(db_name)
    if mongodb then
        local ok, res_oe =  mongodb:create_indexes(coll_name, indexes)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:drop_indexes(db_name, coll_name, index_name)
    local mongodb = self:get_db(db_name)
    if mongodb then
        local ok, res_oe =  mongodb:drop_indexes(coll_name, index_name)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:find_and_modify(db_name, coll_name, obj, selector, upsert, fields)
    local mongodb = self:get_db(db_name)
    if mongodb then
        local ok, res_oe = mongodb:find_and_modify(coll_name, obj, selector, upsert, fields)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:execute(db_name, cmd, ...)
    local mongodb = self:get_db(db_name)
    if mongodb then
        local ok, res_oe = mongodb:runCommand(cmd, ...)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

quanta.mongo_mgr = MongoMgr()

return MongoMgr
