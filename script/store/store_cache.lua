--store_cache.lua

local log_err       = logger.err
local qfailed       = quanta.failed
local deepcopy      = table.deepcopy

local cache_proxy   = quanta.get("cache_proxy")

local Store         = import("store/store.lua")

local StoreCache = class(Store)
local prop = property(StoreCache)
prop:reader("increases", {})    -- increases

function StoreCache:__init(mgr, sheet, primary_id)
end

function StoreCache:load(key)
    local code, data = cache_proxy:load(self.primary_id, self.sheet)
    if qfailed(code) then
        log_err("[StoreMgr][load_{}] primary_id: {} find failed! code: {}, res: {}", self.sheet, self.primary_id, code, data)
        return false
    end
    return true, data
end

function StoreCache:delete()
    self.increases = nil
    local code = cache_proxy:delete(self.primary_id, self.sheet)
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
        self.store_mgr:save_increases(self)
    end
end

function StoreCache:update_field(layers, field, key, value)
    Store.update_field(self, layers, field, key, (value ~= nil) and value or "nil", self.increases)
    if not self.wholes then
        self.store_mgr:save_increases(self)
    end
end

function StoreCache:sync_increase()
    if next(self.increases) then
        local increases = self.increases
        self.increases = {}
        local code = cache_proxy:update(self.primary_id, self.sheet, increases)
        if qfailed(code) then
            log_err("[StoreCache][sync_increase] update {}.{} failed! code: {}", self.sheet, self.primary_id, code)
            deepcopy(self.increases, increases)
            self.increases = increases
            self.store_mgr:save_increases(self)
            return
        end
    end
end

function StoreCache:sync_whole()
    if next(self.increases) then
        deepcopy(self.increases, self.wholes)
        self.increases = {}
    end
    local code = cache_proxy:flush(self.primary_id, self.sheet, self.wholes)
    if qfailed(code) then
        log_err("[StoreCache][sync_whole] flush {}.{} failed! code: {}", self.primary_id, self.sheet, code)
        self.store_mgr:save_wholes(self)
        return
    end
    self.wholes = nil
end

return StoreCache
