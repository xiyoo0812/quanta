--store_cache.lua
import("agent/mongo_agent.lua")
import("agent/cache_agent.lua")

local log_err       = logger.err
local qfailed       = quanta.failed
local deepcopy      = table.deepcopy

local store_mgr     = quanta.get("store_mgr")
local cache_agent   = quanta.get("cache_agent")
local mongo_agent   = quanta.get("mongo_agent")

local Store         = import("store/store.lua")

local StoreCache = class(Store)
local prop = property(StoreCache)
prop:reader("increases", {})    -- increases

function StoreCache:__init(sheet, primary_id)
end

function StoreCache:load(key)
    local code, data = cache_agent:load(self.primary_id, self.sheet)
    if qfailed(code) then
        log_err("[StoreMgr][load_{}] primary_id: {} find failed! code: {}, res: {}", self.sheet, self.primary_id, code, data)
        return false
    end
    return true, data
end

function StoreCache:delete()
    self.increases = nil
    local code = cache_agent:delete(self.primary_id, self.sheet)
    if qfailed(code) then
        log_err("[StoreMgo][delete_{}] primary_id: {} delete failed! code: {}", self.sheet, self.primary_id, code)
    end
end

function StoreCache:flush(obj, timely)
    self.increases = {}
    Store.flush(self, obj, timely)
end

function StoreCache:update_value(layers, key, value)
    Store.update_value(self, layers, key, (value ~= nil) and value or "nil", self.increases)
    if not self.wholes then
        store_mgr:save_increases(self)
    end
end

function StoreCache:update_field(layers, field, key, value)
    Store.update_field(self, layers, field, key, (value ~= nil) and value or "nil", self.increases)
    if not self.wholes then
        logger.debug("[StoreCache][update_field] {}.{} data={}", self.sheet, self.primary_id, self.increases)
        store_mgr:save_increases(self)
    end
end

function StoreCache:sync_increase()
    if next(self.increases) then
        local increases = self.increases
        self.increases = {}
        local code = cache_agent:update(self.primary_id, self.sheet, increases)
        if qfailed(code) then
            log_err("[StoreCache][sync_increase] update {}.{} failed! code: {}", self.sheet, self.primary_id, code)
            deepcopy(self.increases, increases)
            self.increases = increases
            store_mgr:sync_increase(self)
            return
        end
    end
end

function StoreCache:sync_whole()
    if next(self.increases) then
        deepcopy(self.increases, self.wholes)
        self.increases = {}
    end
    local code = cache_agent:flush(self.primary_id, self.sheet, self.wholes)
    if qfailed(code) then
        log_err("[StoreCache][sync_whole] flush {}.{} failed! code: {}", self.primary_id, self.sheet, code)
        store_mgr:save_wholes(self)
        return
    end
    self.wholes = nil
end

--注册驱动
store_mgr:bind_store("cache", StoreCache)
store_mgr:bind_driver("cache", mongo_agent)

return StoreCache
