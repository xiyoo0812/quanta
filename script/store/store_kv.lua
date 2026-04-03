--store_kv.lua
local log_err       = logger.err
local log_dump      = logger.dump

local driver        = quanta.get(environ.get("QUANTA_STORE"))

local Store         = import("store/store.lua")

local StoreKV = class(Store)
local prop = property(StoreKV)
prop:reader("primary_key", "")  -- primary_key

function StoreKV:__init(mgr, heet, primary_id)
end

function StoreKV:load(key)
    self.primary_key = key
    local data, ok = driver:get(self.primary_id, self.sheet)
    if not ok then
        return false
    end
    self.wholes = data or {}
    return true, self.wholes
end

function StoreKV:delete()
    driver:del(self.primary_id, self.sheet)
end

function StoreKV:update_value(layers, key, value)
    Store.update_value(self, layers, key, value)
    self.store_mgr:save_wholes(self)
end

function StoreKV:update_field(layers, field, key, value)
    Store.update_field(self, layers, field, key, value)
    self.store_mgr:save_wholes(self)
end

function StoreKV:sync_whole()
    if not self.wholes[self.primary_key] then
        self.wholes[self.primary_key] = self.primary_id
    end
    log_dump("[StoreKV][sync_whole] {}.{}={}", self.sheet, self.primary_id, self.wholes)
    if not driver:put(self.primary_id, self.wholes, self.sheet) then
        log_err("[StoreKV][sync_whole] sync {}.{} failed!", self.sheet, self.primary_id)
    end
end

return StoreKV
