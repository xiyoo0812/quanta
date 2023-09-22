--mongo_mgr.lua
local log_debug     = logger.debug

local event_mgr     = quanta.get("event_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local MONGO_FAILED  = quanta.enum("KernCode", "MONGO_FAILED")

local AUTOINCCC     = environ.get("QUANTA_DB_AUTOINCTB")
local MAIN_DBID     = environ.number("QUANTA_DB_MAIN_ID")
local BENCHMARK     = environ.number("QUANTA_DB_BENCHMARK")

local MongoMgr = singleton()
local prop = property(MongoMgr)
prop:reader("mongo_dbs", {})    -- mongo_dbs

function MongoMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_mongo_find", "find")
    event_mgr:add_listener(self, "rpc_mongo_count", "count")
    event_mgr:add_listener(self, "rpc_mongo_insert", "insert")
    event_mgr:add_listener(self, "rpc_mongo_delete", "delete")
    event_mgr:add_listener(self, "rpc_mongo_update", "update")
    event_mgr:add_listener(self, "rpc_mongo_execute", "execute")
    event_mgr:add_listener(self, "rpc_mongo_find_one", "find_one")
    event_mgr:add_listener(self, "rpc_mongo_drop_indexes", "drop_indexes")
    event_mgr:add_listener(self, "rpc_mongo_create_indexes", "create_indexes")
    event_mgr:add_listener(self, "rpc_mongo_find_and_modify", "find_and_modify")
    event_mgr:add_listener(self, "rpc_mongo_get_autoinc_id", "get_autoinc_id")
end

--初始化
function MongoMgr:setup()
    local MongoDB = import("driver/mongo.lua")
    local drivers = environ.driver("QUANTA_MONGO_URLS")
    for i, conf in ipairs(drivers) do
        local mongo_db = MongoDB(conf, i)
        self.mongo_dbs[i] = mongo_db
    end
end

--查找mongo db
function MongoMgr:get_db(db_id)
    return self.mongo_dbs[db_id or MAIN_DBID]
end

function MongoMgr:find(db_id, primary_id, coll_name, selector, fields, sortor, limit)
    log_debug("[MongoMgr][find]: {}, selector:{}", coll_name, selector)
    local mongodb = self:get_db(db_id)
    if mongodb and mongodb:set_executer(primary_id) then
        mongodb:set_executer(primary_id)
        local ok, res_oe = mongodb:find(coll_name, selector, fields or {_id = 0}, sortor, limit)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:find_one(db_id, primary_id, coll_name, selector, fields)
    log_debug("[MongoMgr][find_one]: {}, selector:{}", coll_name, selector)
    local mongodb = self:get_db(db_id)
    if mongodb and mongodb:set_executer(primary_id) then
        local ok, res_oe = mongodb:find_one(coll_name, selector, fields or {_id = 0})
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:insert(db_id, primary_id, coll_name, obj)
    log_debug("[MongoMgr][insert]: {}, obj:{}", coll_name, obj)
    local mongodb = self:get_db(db_id)
    if mongodb and mongodb:set_executer(primary_id) then
        local ok, res_oe = mongodb:insert(coll_name, obj)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:update(db_id, primary_id, coll_name, obj, selector, upsert, multi)
    log_debug("[MongoMgr][update]: {}, obj:{}, selector:{}", coll_name, obj, selector)
    local mongodb = self:get_db(db_id)
    if mongodb and mongodb:set_executer(primary_id) then
        local ok, res_oe = mongodb:update(coll_name, obj, selector, upsert, multi)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:delete(db_id, primary_id, coll_name, selector, onlyone)
    log_debug("[MongoMgr][delete]: {}, selector:{}", coll_name, selector)
    local mongodb = self:get_db(db_id)
    if mongodb and mongodb:set_executer(primary_id) then
        local ok, res_oe = mongodb:delete(coll_name, selector, onlyone)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:find_and_modify(db_id, primary_id, coll_name, obj, selector, upsert, fields, new)
    local mongodb = self:get_db(db_id)
    if mongodb and mongodb:set_executer(primary_id) then
        local ok, res_oe = mongodb:find_and_modify(coll_name, obj, selector, upsert, fields, new)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:count(db_id, coll_name, selector, limit, skip)
    local mongodb = self:get_db(db_id)
    if mongodb then
        local ok, res_oe = mongodb:count(coll_name, selector, limit, skip)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:create_indexes(db_id, coll_name, indexes)
    local mongodb = self:get_db(db_id)
    if mongodb then
        local ok, res_oe =  mongodb:create_indexes(coll_name, indexes)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:drop_indexes(db_id, coll_name, index_name)
    local mongodb = self:get_db(db_id)
    if mongodb then
        local ok, res_oe =  mongodb:drop_indexes(coll_name, index_name)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:get_autoinc_id(db_id, id_key)
    local query = { key = id_key }
    local fields = { autoinc_id = 1 }
    local update = { ["$inc"] = { ["autoinc_id"] = 1 } }
    local code, res = self:find_and_modify(db_id, AUTOINCCC, update, query, true, fields, true)
    if code == MONGO_FAILED then
        return MONGO_FAILED, res
    end
    local origin_id = res.value.autoinc_id
    if BENCHMARK then
        return SUCCESS, BENCHMARK + origin_id
    end
    return SUCCESS, origin_id
end

function MongoMgr:execute(db_id, primary_id, cmd, ...)
    local mongodb = self:get_db(db_id)
    if mongodb and mongodb:set_executer(primary_id) then
        local ok, res_oe = mongodb:runCommand(cmd, ...)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:available(db_id)
    local redisdb = self:get_db(db_id)
    if not redisdb then
        return false
    end
    return redisdb:available()
end

quanta.mongo_mgr = MongoMgr()

return MongoMgr
