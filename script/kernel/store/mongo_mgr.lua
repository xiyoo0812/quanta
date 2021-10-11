--mongo_mgr.lua
local tinsert       = table.insert
local hash_code     = utility.hash_code

local DBGroup       = enum("DBGroup")
local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local MONGO_FAILED  = KernCode.MONGO_FAILED

local config_mgr    = quanta.get("config_mgr")

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
    local database = config_mgr:get_table("database")
    for _, conf in database:iterator() do
        if group == conf.group and conf.driver == "mongo" then
            self.mongo_dbs[conf.index] = MongoDB(conf)
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

function MongoMgr:find(index, coll_name, selector, fields, sortor, limit)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:find(coll_name, selector, fields, sortor, limit)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:collect(coll_name, selector, fields, sortor, limit)
    local collect_res = {}
    if limit then
        for _, mongodb in pairs(self.mongo_dbs) do
            local ok, res_oe = mongodb:find(coll_name, selector, fields, sortor, limit)
            if ok then
                for _, record in pairs(res_oe) do
                    if #collect_res > limit then
                        return SUCCESS, collect_res
                    end
                    tinsert(collect_res, record)
                end
            end
        end
    end
    return SUCCESS, collect_res
end

function MongoMgr:find_one(index, coll_name, selector, fields)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:find_one(coll_name, selector, fields)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:insert(index, coll_name, obj)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:insert(coll_name, obj)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:update(index, coll_name, obj, selector, upsert, multi)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:update(coll_name, obj, selector, upsert, multi)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:delete(index, coll_name, selector, onlyone)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:delete(coll_name, selector, onlyone)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:count(index, coll_name, selector, limit, skip)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:count(coll_name, selector, limit, skip)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:create_indexes(index, coll_name, indexes)
    if index == 0 then
        for _, mongodb in pairs(self.mongo_dbs) do
            local ok, res_oe =  mongodb:create_indexes(coll_name, indexes)
            if not ok then
                return MONGO_FAILED, res_oe
            end
        end
        return SUCCESS
    end
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe =  mongodb:create_indexes(coll_name, indexes)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:drop_indexes(index, coll_name, index_name)
    if index == 0 then
        for _, mongodb in pairs(self.mongo_dbs) do
            local ok, res_oe =  mongodb:drop_indexes(coll_name, index_name)
            if not ok then
                return MONGO_FAILED, res_oe
            end
        end
        return SUCCESS
    end
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe =  mongodb:drop_indexes(coll_name, index_name)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:execute(index, cmd, ...)
    local mongodb = self:get_db(index)
    if mongodb then
        local ok, res_oe = mongodb:runCommand(cmd, ...)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

return MongoMgr
