--store_mgo.lua
import("agent/mongo_proxy.lua")

local log_err       = logger.err
local qfailed       = quanta.failed

local mongo_proxy   = quanta.get("mongo_proxy")

local Store         = import("store/store.lua")

local StoreMgo = class(Store)
local prop = property(StoreMgo)
prop:reader("primary_key", "")  -- primary_key

function StoreMgo:__init(mgr, sheet, primary_id)
end

function StoreMgo:load(key)
    self.primary_key = key
    local primary_id = self.primary_id
    local ok, code, data = mongo_proxy:find_one({ self.sheet, { [key] = primary_id }}, primary_id)
    if qfailed(code, ok) then
        log_err("[StoreMgo][load_{}] primary_id: {} find failed! code: {}, res: {}", self.sheet, primary_id, code, data)
        return false
    end
    self.wholes = data or {}
    return true, self.wholes
end

function StoreMgo:delete()
    self.wholes = nil
    local primary_id = self.primary_id
    local ok, code, data = mongo_proxy:delete({ self.sheet, { [self.primary_key] = primary_id }, true}, primary_id)
    if qfailed(code, ok) then
        log_err("[StoreMgo][load_{}] primary_id: {} find failed! code: {}, res: {}", self.sheet, primary_id, code, data)
    end
end

function StoreMgo:update_value(layers, key, value)
    Store.update_value(self, layers, key, value)
    self.store_mgr:save_wholes(self)
end

function StoreMgo:update_field(layers, field, key, value)
    Store.update_field(self, layers, field, key, value)
    self.store_mgr:save_wholes(self)
end

function StoreMgo:sync_whole()
    local primary_id = self.primary_id
    local primary_key = self.primary_key
    if not self.wholes[primary_key] then
        self.wholes[primary_key] = primary_id
    end
    local ok, code, adata = mongo_proxy:update({ self.sheet, self.wholes, {[primary_key] = primary_id }, true}, primary_id)
    if qfailed(code, ok) then
        log_err("[StoreMgo][sync_whole] flush {}.{} failed! code: {}, res: {}", self.sheet, primary_id, code, adata)
    end
end

return StoreMgo
