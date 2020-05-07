--mongo_mgr.lua
local driver        = require("driver.mongo")

local pcall         = pcall
local tinsert       = table.insert
local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn
local env_number    = environ.number

local router_mgr    = quanta.router_mgr
local timer_mgr     = quanta.timer_mgr
local config_mgr    = quanta.config_mgr

local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local MONGO_FAILED  = KernCode.MONGO_FAILED

local CONNECT_WAIT_TIME = 5
local PERIOD_UPDATE     = 1000

local MongoMgr = singleton()
function MongoMgr:__init()
    self.mongo_svrs = {}
    self:setup()
end

--初始化
function MongoMgr:setup()
    config_mgr:init_table("database", "group", "index")
    local group = env_number("QUANTA_MONGO")
    local database = config_mgr:get_table("database")
    for _, conf in database:iterator() do
        if conf.group == group and conf.driver == "mongo" then
            local db_conf = {db = conf.db, host = conf.host, port = conf.port}
            self.mongo_svrs[conf.index] = {cfg = db_conf, connect_tick = 0}
        end
    end
    --update
    timer_mgr:loop(PERIOD_UPDATE, function()
        self:check_dbs()
    end)
    router_mgr:add_listener(self, "mongo_find")
    router_mgr:add_listener(self, "mongo_insert")
    router_mgr:add_listener(self, "mongo_delete")
    router_mgr:add_listener(self, "mongo_update")
    router_mgr:add_listener(self, "mongo_find_one")
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
    local do_find = function()
        local collection = self:find_collection(dbid, coll_name)
        if collection then
            local result = {}
            local cursor = collection:find(selector, fields)
            if sorts then cursor:sort(table.unpack(sorts)) end
            if limit then cursor:limit(limit) end
            while cursor do
                local err, hasnext = cursor:hasNext()
                if 0 ~= err then
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
    local collection = self:find_collection(dbid, coll_name)
    if collection then
        local ok, err, result = pcall(collection.findOne, collection, selector, fields)
        if ok then  -- 代码执行成功
            if 0 ~= err then  -- 网络错误
                self:on_network_err(dbid)
                return MONGO_FAILED, "mongo network error"
            else  -- mongo执行成功
                return SUCCESS, result
            end
        else  -- 代码执行失败
            return MONGO_FAILED, err
        end
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:mongo_insert(dbid, coll_name, obj)
    local collection = self:find_collection(dbid, coll_name)
    if collection then
        -- 执行结果，网络错误or支持错误信息
        local ok, err, mongo_ok, err_msg, result = pcall(collection.safe_insert, collection, obj)
        if ok then
            if 0 == err then
                return mongo_ok and SUCCESS or MONGO_FAILED, mongo_ok and result or err_msg
            else
                self:on_network_err(dbid)
                return MONGO_FAILED, "mongo network error"
            end
        else
            return MONGO_FAILED, err
        end
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:mongo_update(dbid, coll_name, obj, selector, upsert, multi)
    local collection = self:find_collection(dbid, coll_name)
    if collection then
        local ok, err, mongo_ok, err_msg, result = pcall(collection.safe_update, collection, selector, obj, upsert, multi)
        if ok then
            if 0 == err then
                return mongo_ok and SUCCESS or MONGO_FAILED, mongo_ok and result or err_msg
            else
                self:on_network_err(dbid)
                return MONGO_FAILED, "mongo network error"
            end
        else
            return MONGO_FAILED, err
        end
    end
    return MONGO_FAILED, "mongo db not exist"
end

function MongoMgr:mongo_delete(dbid, coll_name, selector, single)
    local collection = self:find_collection(dbid, coll_name)
    if collection then
        local ok, err, mongo_ok, err_msg, result = pcall(collection.safe_delete, collection, selector, single)
        if ok then
            if 0 == err then
                return mongo_ok and SUCCESS or MONGO_FAILED, mongo_ok and result or err_msg
            else
                self:on_network_err(dbid)
                return MONGO_FAILED, "mongo network error"
            end
        else
            return MONGO_FAILED, err
        end
    end
    return MONGO_FAILED, "mongo db not exist"
end

quanta.mongo_mgr = MongoMgr()

return MongoMgr
