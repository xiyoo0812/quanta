--mongo_mgr.lua
local driver        = require("driver.mongo")
local MONGO_CFGS    = import("config/mongo_cfg.lua")

local type          = type
local pcall         = pcall
local tinsert       = table.insert
local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn
local env_number    = environ.number

local router_mgr    = quanta.router_mgr
local timer_mgr     = quanta.timer_mgr

local errcode       = err.Code
local SUCCESS       = errcode.SUCCESS
local MONGO_FAILED  = errcode.MONGO_FAILED

local CONNECT_WAIT_TIME = 5
local PERIOD_UPDATE     = 1000

local MongoMgr = singleton()
function MongoMgr:__init()
    self.mongo_svrs = {}
    self:setup()
end

--初始化
function MongoMgr:setup()
    local options = quanta.options
    self.enable_dbagent = options.enable_dbagent or 1

    local cfg_id = env_number("ENV_MONGO_GROUP")
    if MONGO_CFGS[cfg_id] then
        for id, dbconf in pairs(MONGO_CFGS[cfg_id]) do
            self.mongo_svrs[id] = {cfg = dbconf, connect_tick = 0}
        end
    else
        log_err("mongo config %d is nil!!", cfg_id)
    end
    --update
    timer_mgr:loop(PERIOD_UPDATE, function()
        self:check_dbs()
    end)

    --注册事件
    if 1 == self.enable_dbagent then
        router_mgr:add_listener(self, "mongo_find")
        router_mgr:add_listener(self, "mongo_insert")
        router_mgr:add_listener(self, "mongo_delete")
        router_mgr:add_listener(self, "mongo_update")
        router_mgr:add_listener(self, "mongo_find_one")
    end
end

function MongoMgr:create_db(id, node)
    local db_name = node.cfg.db
    local ok, client = pcall(driver.client, node.cfg)
    if not ok or not client then
        log_err("mongo create db %d->(host:%s, db=%s) failed!", id, node.cfg.host, db_name)
        return
    end
    log_info("mongo db %d->(host:%s, db=%s) has ready!", id, node.cfg.host, db_name)
    client:getDB(db_name)

    return client[db_name]
end

-- mongo网络
function MongoMgr:on_network_err(dbid)
    local node = self.mongo_svrs[dbid]
    if not node then
        return
    end
    log_warn("[MongoMgr][on_network_err] dbid=%s,host=%s,db=%s", dbid, node.cfg.host, node.cfg.db)
    local db = node.db
    if db then
        local client = db.connection
        if client then
            client:disconnect()
            db.connection = nil
        end
        node.db = nil
    end
    node.connect_tick = 0
end

--查找mongo collection
function MongoMgr:find_collection(dbid, coll_name)
    local node = self.mongo_svrs[dbid]
    if node and node.db then
        return node.db:getCollection(coll_name)
    end
end

--检查mongo连接情况
function MongoMgr:check_dbs()
    for id, node in pairs(self.mongo_svrs) do
        if not node.db then
            if quanta.now > node.connect_tick then
                node.db = self:create_db(id, node)
                if not node.db then
                    node.connect_tick = quanta.now + CONNECT_WAIT_TIME
                end
            end
        end
    end
end

function MongoMgr:mongo_find(dbid, coll_name, selector, fields, sorts, limit)
    if type(coll_name) ~= "string" then
        return MONGO_FAILED, "mongo query params error"
    end

    local do_find = function()
        local collection = self:find_collection(dbid, coll_name)
        if collection then
            local result = {}
            local cursor = collection:find(selector, fields)
            if sorts then cursor:sort(table.unpack(sorts)) end
            if limit then cursor:limit(limit) end
            while cursor do
                local sock_err, hasnext = cursor:hasNext()
                if 0 ~= sock_err then
                    return MONGO_FAILED, "mongo network error"
                end
                if not hasnext then
                    break
                end
                local doc = cursor:next()
                tinsert(result, doc)
            end
            return SUCCESS, result
        end

        return MONGO_FAILED, "mongo db not exist"
    end

    local ok, code, result = pcall(do_find)
    if not ok then
        result = code
        code   = MONGO_FAILED
    end

    return code, result
end

function MongoMgr:mongo_find_one(dbid, coll_name, selector, fields)
    if type(coll_name) ~= "string" then
        return MONGO_FAILED, "mongo query params error"
    end
    local collection = self:find_collection(dbid, coll_name)
    if collection then
        local ok, sock_err, result = pcall(collection.findOne, collection, selector, fields)
        if ok then  -- 代码执行成功
            if 0 ~= sock_err then  -- 网络错误
                self:on_network_err(dbid)
                return MONGO_FAILED, "mongo network error"
            else  -- mongo执行成功
                return SUCCESS, result
            end
        else  -- 代码执行失败
            return MONGO_FAILED, sock_err
        end
    end

    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:mongo_insert(dbid, coll_name, obj)
    if type(coll_name) ~= "string" then
        return MONGO_FAILED, "mongo query params error"
    end
    local collection = self:find_collection(dbid, coll_name)
    if collection then
        -- 执行结果，网络错误or支持错误信息
        local call_ok, serr_or_err, mongo_ok, err_msg, result = pcall(collection.safe_insert, collection, obj)
        if call_ok then
            if 0 == serr_or_err then
                return mongo_ok and SUCCESS or MONGO_FAILED, mongo_ok and result or err_msg
            else
                self:on_network_err(dbid)
                return MONGO_FAILED, "mongo network error"
            end
        else
            return MONGO_FAILED, serr_or_err
        end
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:mongo_update(dbid, coll_name, obj, selector, upsert, multi)
    if type(coll_name) ~= "string" then
        return MONGO_FAILED, "mongo query params error"
    end
    local collection = self:find_collection(dbid, coll_name)
    if collection then
        local call_ok, serr_or_err, mongo_ok, err_msg, result = pcall(collection.safe_update, collection, selector, obj, upsert, multi)
        if call_ok then
            if 0 == serr_or_err then
                return mongo_ok and SUCCESS or MONGO_FAILED, mongo_ok and result or err_msg
            else
                self:on_network_err(dbid)
                return MONGO_FAILED, "mongo network error"
            end
        else
            return MONGO_FAILED, serr_or_err
        end
    end

    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:mongo_delete(dbid, coll_name, selector, single)
    if type(coll_name) ~= "string" then
        return MONGO_FAILED, "mongo query params error"
    end
    local collection = self:find_collection(dbid, coll_name)
    if collection then
        local call_ok, serr_or_err, mongo_ok, err_msg, result = pcall(collection.safe_delete, collection, selector, single)
        if call_ok then
            if 0 == serr_or_err then
                return mongo_ok and SUCCESS or MONGO_FAILED, mongo_ok and result or err_msg
            else
                self:on_network_err(dbid)
                return MONGO_FAILED, "mongo network error"
            end
        else
            return MONGO_FAILED, serr_or_err
        end
    end
    return MONGO_FAILED, "mongo db not exist"
end

quanta.mongo_mgr = MongoMgr()

--[[
function MongoMgr:test()
    self:insert("test_mongo", {player_id = 1, name = "123"})
    self:insert("test_mongo", {player_id = 2, name = "234"})
    self:insert("test_mongo", {player_id = 3, name = "345"})
    local all = self:find("test_mongo", {}, {_id = 0})
    log_info("find test_mongo all: %s", serialize(all))
    local one = self:find_one("test_mongo", {player_id = 2}, {_id = 0})
    log_info("find test_mongo one: %d = %s", 2, serialize(one))
    self:update("test_mongo", {player_id = 2, name = "2234"}, {player_id = 2})
    local one2 = self:find_one("test_mongo", {player_id = 2}, {_id = 0})
    log_info("find test_mongo update one: %d = %s", 2, serialize(one2))
    self:update("test_mongo", {player_id = 4, name = "456"}, {player_id = 4}, true)
    local all2 = self:find("test_mongo", {}, {_id = 0})
    log_info("find test_mongo update all: %s", serialize(all2))
    self:delete("test_mongo", {player_id = 2})
    local all3 = self:find("test_mongo", {}, {_id = 0})
    log_info("find test_mongo delete all: %s", serialize(all3))
end
--]]

return MongoMgr
