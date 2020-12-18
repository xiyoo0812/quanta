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
    self.global_dbs = {}
    self.game_dbs = {}
    self:setup()
end

--初始化
function MongoMgr:setup()
    local game_group = env_number("QUANTA_DBGRP_GAME")
    local global_group = env_number("QUANTA_DBGRP_GLOBAL")
    if game_group and global_group then
        local database = config_mgr:init_table("database", "group", "index")
        for _, conf in database:iterator() do
            if conf.group == game_group and conf.driver == "mongo" then
                self.game_dbs[conf.index] = MongoDB(conf.db, conf.host, conf.port)
            end
            if conf.group == global_group and conf.driver == "mongo" then
                self.global_dbs[conf.index] = MongoDB(conf.db, conf.host, conf.port)
            end
        end
        event_mgr:add_listener(self, "game_find")
        event_mgr:add_listener(self, "game_insert")
        event_mgr:add_listener(self, "game_delete")
        event_mgr:add_listener(self, "game_update")
        event_mgr:add_listener(self, "game_find_one")
        event_mgr:add_listener(self, "game_count")
        event_mgr:add_listener(self, "global_find")
        event_mgr:add_listener(self, "global_insert")
        event_mgr:add_listener(self, "global_delete")
        event_mgr:add_listener(self, "global_update")
        event_mgr:add_listener(self, "global_find_one")
    end
end

--查找mongo collection
function MongoMgr:get_game_db(dbid, coll_name)
    return self.game_dbs[dbid]
end

--查找mongo collection
function MongoMgr:get_global_db(dbid, coll_name)
    return self.global_dbs[dbid]
end

function MongoMgr:game_find(dbid, coll_name, query, selector, limit, query_num)
    local mongodb = self:get_game_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:find(coll_name, query, selector, limit, query_num)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:game_find_one(dbid, coll_name, query, selector)
    local mongodb = self:get_game_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:find_one(coll_name, query, selector)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:game_insert(dbid, coll_name, obj)
    local mongodb = self:get_game_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:insert(coll_name, obj)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:game_update(dbid, coll_name, obj, selector, upsert, multi)
    local mongodb = self:get_game_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:update(coll_name, obj, selector, upsert, multi)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:game_delete(dbid, coll_name, selector, onlyone)
    local mongodb = self:get_game_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:delete(coll_name, selector, onlyone)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:game_count(dbid, coll_name, selector, limit, skip)
    local mongodb = self:get_game_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:count(coll_name, selector, limit, skip)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "game mongo db not exist"
end

function MongoMgr:global_find(dbid, coll_name, query, selector, limit, query_num)
    local mongodb = self:get_global_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:find(coll_name, query, selector, limit, query_num)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

function MongoMgr:global_find_one(dbid, coll_name, query, selector)
    local mongodb = self:get_global_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:find_one(coll_name, query, selector)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

function MongoMgr:global_insert(dbid, coll_name, obj)
    local mongodb = self:get_global_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:insert(coll_name, obj)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

function MongoMgr:global_update(dbid, coll_name, obj, selector, upsert, multi)
    local mongodb = self:get_global_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:update(coll_name, obj, selector, upsert, multi)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

function MongoMgr:global_delete(dbid, coll_name, selector, onlyone)
    local mongodb = self:get_global_db(dbid)
    if mongodb then
        local ok, res_oe = mongodb:delete(coll_name, selector, onlyone)
        return ok and SUCCESS or MONGO_FAILED, res_oe
    end
    return MONGO_FAILED, "rmsg mongo db not exist"
end

quanta.mongo_mgr = MongoMgr()

return MongoMgr
