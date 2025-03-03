--store_kv.lua
local log_err       = logger.err
local log_dump      = logger.dump

local store_mgr     = quanta.get("store_mgr")

local QUANTA_STORE  = environ.get("QUANTA_STORE")

local Store         = import("store/store.lua")

local StoreKV = class(Store)
local prop = property(StoreKV)
prop:reader("primary_key", "")  -- primary_key

function StoreKV:__init(sheet, primary_id)
    self.driver = store_mgr:get_driver()
end

function StoreKV:load(key)
    self.primary_key = key
    local data, ok = self.driver:get(self.primary_id, self.sheet)
    if not ok then
        return false
    end
    self.wholes = data or {}
    return true, self.wholes
end

function StoreKV:delete()
    self.driver:del(self.primary_id, self.sheet)
end

function StoreKV:update_value(layers, key, value)
    Store.update_value(self, layers, key, value)
    store_mgr:save_wholes(self)
end

function StoreKV:update_field(layers, field, key, value)
    Store.update_field(self, layers, field, key, value)
    store_mgr:save_wholes(self)
end

function StoreKV:sync_whole()
    if not self.wholes[self.primary_key] then
        self.wholes[self.primary_key] = self.primary_id
    end
    log_dump("[StoreKV][sync_whole] {}.{}={}", self.primary_id, self.sheet, self.wholes)
    if not self.driver:put(self.primary_id, self.wholes, self.sheet) then
        log_err("[StoreKV][sync_whole] sync {}.{} failed!", self.primary_id, self.sheet)
    end
end

if QUANTA_STORE == "sqlite" then
    import("driver/sqlite.lua")
    store_mgr:bind_store(QUANTA_STORE, StoreKV)
    store_mgr:bind_driver(QUANTA_STORE, quanta.sdb_driver)
elseif QUANTA_STORE == "lmdb" then
    import("driver/lmdb.lua")
    store_mgr:bind_store(QUANTA_STORE, StoreKV)
    store_mgr:bind_driver(QUANTA_STORE, quanta.mdb_driver)
elseif QUANTA_STORE == "smdb" then
    import("driver/smdb.lua")
    store_mgr:bind_store(QUANTA_STORE, StoreKV)
    store_mgr:bind_driver(QUANTA_STORE, quanta.sdb_driver)
end

return StoreKV
