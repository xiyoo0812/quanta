--mongo_mgr.lua
local MongoDB       = import("driver/mongo.lua")

local env_number    = environ.number

local event_mgr     = quanta.event_mgr
local config_mgr    = quanta.config_mgr

local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local MONGO_FAILED  = KernCode.MONGO_FAILED

local MongoMgr = singleton()
function MongoMgr:__init()
    self.rmsg_dbs = {}
    self.mongo_dbs = {}
    self.rmsg_db_size = 0
    self.mongo_db_size = 0
    self:setup()
end

--初始化
function MongoMgr:setup()
    local rmsg_group = env_number("QUANTA_RMSG")
    local mongo_group = env_number("QUANTA_MONGO")
    if mongo_group and rmsg_group then
        local database = config_mgr:init_table("database", "group", "index")
        for _, conf in database:iterator() do
            if conf.group == mongo_group and conf.driver == "mongo" then
                self.mongo_dbs[conf.index] = MongoDB(conf.db, conf.host, conf.port)
                self.mongo_db_size = self.mongo_db_size + 1
            end
            if conf.group == rmsg_group and conf.driver == "mongo" then
                self.rmsg_dbs[conf.index] = MongoDB(conf.db, conf.host, conf.port)
                self.rmsg_db_size = self.rmsg_db_size + 1
            end
        end
        event_mgr:add_listener(self, "mongo_find")
        event_mgr:add_listener(self, "mongo_insert")
        event_mgr:add_listener(self, "mongo_delete")
        event_mgr:add_listener(self, "mongo_update")
        event_mgr:add_listener(self, "mongo_find_one")
        event_mgr:add_listener(self, "mongo_count")
        event_mgr:add_listener(self, "rmsg_find")
        event_mgr:add_listener(self, "rmsg_insert")
        event_mgr:add_listener(self, "rmsg_delete")
        event_mgr:add_listener(self, "rmsg_update")
        event_mgr:add_listener(self, "rmsg_find_one")
    end
end

--查找mongo collection
function MongoMgr:get_mongo_db(dbid, coll_name)
    local real_dbid = (dbid % self.mongo_db_size) + 1
    return self.mongo_dbs[real_dbid]
end

--查找mongo collection
function MongoMgr:get_rmsg_db(dbid, coll_name)
    local real_dbid = (dbid % self.rmsg_db_size) + 1
    return self.rmsg_dbs[real_dbid]
end

function MongoMgr:mongo_find(dbid, coll_name, query, selector, limit, query_num)
    local mongodb = self:get_mongo_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:find(coll_name, query, selector, limit, query_num)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:mongo_find_one(dbid, coll_name, query, selector)
    local mongodb = self:get_mongo_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:find_one(coll_name, query, selector)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:mongo_insert(dbid, coll_name, obj)
    local mongodb = self:get_mongo_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:insert(coll_name, obj)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:mongo_update(dbid, coll_name, obj, selector, upsert, multi)
    local mongodb = self:get_mongo_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:update(coll_name, obj, selector, upsert, multi)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:mongo_delete(dbid, coll_name, selector, onlyone)
    local mongodb = self:get_mongo_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:delete(coll_name, selector, onlyone)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:mongo_count(dbid, coll_name, selector, limit, skip)
    local mongodb = self:get_mongo_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:count(coll_name, selector, limit, skip)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:rmsg_find(dbid, coll_name, query, selector, limit, query_num)
    local mongodb = self:get_rmsg_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:find(coll_name, query, selector, limit, query_num)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

function MongoMgr:rmsg_find_one(dbid, coll_name, query, selector)
    local mongodb = self:get_rmsg_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:find_one(coll_name, query, selector)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

function MongoMgr:rmsg_insert(dbid, coll_name, obj)
    local mongodb = self:get_rmsg_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:insert(coll_name, obj)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

function MongoMgr:rmsg_update(dbid, coll_name, obj, selector, upsert, multi)
    local mongodb = self:get_rmsg_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:update(coll_name, obj, selector, upsert, multi)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

function MongoMgr:rmsg_delete(dbid, coll_name, selector, onlyone)
    local mongodb = self:get_rmsg_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:delete(coll_name, selector, onlyone)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

quanta.mongo_mgr = MongoMgr()

return MongoMgr
