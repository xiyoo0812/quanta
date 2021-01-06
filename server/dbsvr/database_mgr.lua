--database_mgr.lua

local event_mgr = quanta.event_mgr

local DatabaseMgr = singleton()
local prop = property(DatabaseMgr)
prop:accessor("database_mgrs", {})      -- database mgrs

function DatabaseMgr:__init()
    -- 注册事件
    event_mgr:add_listener(self, "find")
    event_mgr:add_listener(self, "insert")
    event_mgr:add_listener(self, "delete")
    event_mgr:add_listener(self, "update")
    event_mgr:add_listener(self, "find_one")
    event_mgr:add_listener(self, "count")
end

--返回数据库管理器
function DatabaseMgr:get_databese_mgr(db_group)
    local database_mgr = self.database_mgrs[db_group]
    if database_mgr then
        return database_mgr
    end
    if self.cache_driver == "mnogo" then
        local MongoMgr = import("kernel/store/mongo_mgr.lua")
        local mongo_mgr = MongoMgr(db_group)
        self.database_mgrs[db_group] = mongo_mgr
        return mongo_mgr
    end
end

function DatabaseMgr:find(db_group, index, coll_name, query, selector, limit, query_num)
    local database_mgr = self:get_databese_mgr(db_group)
    return database_mgr:find(index, coll_name, query, selector, limit, query_num)
end

function DatabaseMgr:find_one(db_group, index, coll_name, query, selector)
    local database_mgr = self:get_databese_mgr(db_group)
    return database_mgr:find_one(index, coll_name, query, selector)
end

function DatabaseMgr:insert(db_group, index, coll_name, obj)
    local database_mgr = self:get_databese_mgr(db_group)
    return database_mgr:insert(index, coll_name, obj)
end

function DatabaseMgr:update(db_group, index, coll_name, obj, selector, upsert, multi)
    local database_mgr = self:get_databese_mgr(db_group)
    return database_mgr:update(index, coll_name, obj, selector, upsert, multi)
end

function DatabaseMgr:delete(db_group, index, coll_name, selector, onlyone)
    local database_mgr = self:get_databese_mgr(db_group)
    return database_mgr:delete(index, coll_name, selector, onlyone)
end

function DatabaseMgr:count(db_group, index, coll_name, selector, limit, skip)
    local database_mgr = self:get_databese_mgr(db_group)
    return database_mgr:count(index, coll_name, selector, limit, skip)
end

quanta.database_mgr = DatabaseMgr()

return DatabaseMgr
