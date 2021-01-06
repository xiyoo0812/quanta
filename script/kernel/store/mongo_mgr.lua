--mongo_mgr.lua
local hash_code     = utility.hash_code

local DBGroup       = enum("DBGroup")
local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local MONGO_FAILED  = KernCode.MONGO_FAILED

local config_mgr    = quanta.config_mgr

local MongoMgr = class()
local prop = property(MongoMgr)
prop:accessor("hash_mode", false)   -- hash_mode
prop:accessor("mongo_dbs", {})      -- mongo_dbs

function MongoMgr:__init(group)
    self:setup(group)
    self.hash_mode = (group == DBGroup.HASH)
end

--初始化
function MongoMgr:setup(group)
    local MongoDB = import("driver/mongo.lua")
    local database = config_mgr:init_table("database", "group", "index")
    for _, conf in database:iterator() do
        if group == conf.group and conf.driver == "mongo" then
            self.mongo_dbs[conf.index] = MongoDB(conf.db, conf.host, conf.port)
        end
    end
end

--查找mongo db
function MongoMgr:get_db(index)
    if self.hash_mode then
        local hash_index = hash_code(index, #self.mongo_dbs)
        return self.mongo_dbs[hash_index]
    end
    return self.mongo_dbs[index]
end

function MongoMgr:find(index, coll_name, query, selector, limit, query_num)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:find(coll_name, query, selector, limit, query_num)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:find_one(index, coll_name, query, selector)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:find_one(coll_name, query, selector)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:insert(index, coll_name, obj)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:insert(coll_name, obj)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:update(index, coll_name, obj, selector, upsert, multi)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:update(coll_name, obj, selector, upsert, multi)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:delete(index, coll_name, selector, onlyone)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:delete(coll_name, selector, onlyone)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:count(index, coll_name, selector, limit, skip)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:count(coll_name, selector, limit, skip)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

return MongoMgr
