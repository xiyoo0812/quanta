--mongo_mgr.lua
local MongoDB       = import("driver/mongo.lua")

local env_number    = environ.number
local env_status    = environ.status

local event_mgr     = quanta.event_mgr
local config_mgr    = quanta.config_mgr

local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local MONGO_FAILED  = KernCode.MONGO_FAILED

local MongoMgr = singleton()
function MongoMgr:__init()
    self.game_mongos = {}
    self.rmsg_mongos = {}
    self.game_mongo_size = 0
    self.rmsg_mongo_size = 0
    self:setup()
end

--初始化
function MongoMgr:setup()
    if env_status("QUANTA_MONGO") then
        local game_group = env_number("QUANTA_GAME")
        local rmsg_group = env_number("QUANTA_RMSG")
        local database = config_mgr:init_table("database", "group", "index")
        for _, conf in database:iterator() do
            if conf.group == game_group and conf.driver == "mongo" then
                self.game_mongos[conf.index] = MongoDB(conf.db, conf.host, conf.port)
                self.game_mongo_size = self.game_mongo_size + 1
            end
            if conf.group == rmsg_group and conf.driver == "mongo" then
                self.rmsg_mongos[conf.index] = MongoDB(conf.db, conf.host, conf.port)
                self.rmsg_mongo_size = self.rmsg_mongo_size + 1
            end
        end
        event_mgr:add_listener(self, "game_mongo_find")
        event_mgr:add_listener(self, "game_mongo_insert")
        event_mgr:add_listener(self, "game_mongo_delete")
        event_mgr:add_listener(self, "game_mongo_update")
        event_mgr:add_listener(self, "game_mongo_find_one")
        event_mgr:add_listener(self, "game_mongo_count")
        event_mgr:add_listener(self, "rmsg_mongo_find")
        event_mgr:add_listener(self, "rmsg_mongo_insert")
        event_mgr:add_listener(self, "rmsg_mongo_delete")
        event_mgr:add_listener(self, "rmsg_mongo_update")
        event_mgr:add_listener(self, "rmsg_mongo_find_one")
    end
end

--查找mongo collection
function MongoMgr:get_game_mongo(dbid, coll_name)
    local real_dbid = (dbid % self.game_mongo_size) + 1
    return self.game_mongos[real_dbid]
end

--查找mongo collection
function MongoMgr:get_rmsg_mongo(dbid, coll_name)
    local real_dbid = (dbid % self.rmsg_mongo_size) + 1
    return self.rmsg_mongos[real_dbid]
end

function MongoMgr:game_mongo_find(dbid, coll_name, query, selector, limit, query_num)
    local mongodb = self:get_game_mongo(dbid)
    if mongodb then
        local ok, res_oe = mongodb:find(coll_name, query, selector, limit, query_num)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:game_mongo_find_one(dbid, coll_name, query, selector)
    local mongodb = self:get_game_mongo(dbid)
    if mongodb then
        local ok, res_oe = mongodb:find_one(coll_name, query, selector)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:game_mongo_insert(dbid, coll_name, obj)
    local mongodb = self:get_game_mongo(dbid)
    if mongodb then
        local ok, res_oe = mongodb:insert(coll_name, obj)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:game_mongo_update(dbid, coll_name, obj, selector, upsert, multi)
    local mongodb = self:get_game_mongo(dbid)
    if mongodb then
        local ok, res_oe = mongodb:update(coll_name, obj, selector, upsert, multi)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:game_mongo_delete(dbid, coll_name, selector, onlyone)
    local mongodb = self:get_game_mongo(dbid)
    if mongodb then
        local ok, res_oe = mongodb:delete(coll_name, selector, onlyone)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:game_mongo_count(dbid, coll_name, selector, limit, skip)
    local mongodb = self:get_game_mongo(dbid)
    if mongodb then
        local ok, res_oe = mongodb:count(coll_name, selector, limit, skip)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:rmsg_mongo_find(dbid, coll_name, query, selector, limit, query_num)
    local mongodb = self:get_rmsg_mongo(dbid)
    if mongodb then
        local ok, res_oe = mongodb:find(coll_name, query, selector, limit, query_num)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

function MongoMgr:rmsg_mongo_find_one(dbid, coll_name, query, selector)
    local mongodb = self:get_rmsg_mongo(dbid)
    if mongodb then
        local ok, res_oe = mongodb:find_one(coll_name, query, selector)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

function MongoMgr:rmsg_mongo_insert(dbid, coll_name, obj)
    local mongodb = self:get_rmsg_mongo(dbid)
    if mongodb then
        local ok, res_oe = mongodb:insert(coll_name, obj)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

function MongoMgr:rmsg_mongo_update(dbid, coll_name, obj, selector, upsert, multi)
    local mongodb = self:get_rmsg_mongo(dbid)
    if mongodb then
        local ok, res_oe = mongodb:update(coll_name, obj, selector, upsert, multi)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

function MongoMgr:rmsg_mongo_delete(dbid, coll_name, selector, onlyone)
    local mongodb = self:get_rmsg_mongo(dbid)
    if mongodb then
        local ok, res_oe = mongodb:delete(coll_name, selector, onlyone)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

quanta.mongo_mgr = MongoMgr()

return MongoMgr
