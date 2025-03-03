--store_mgo.lua
import("agent/mongo_agent.lua")

local log_err       = logger.err
local qfailed       = quanta.failed

local store_mgr     = quanta.get("store_mgr")
local mongo_agent   = quanta.get("mongo_agent")

local Store         = import("store/store.lua")

local StoreMgo = class(Store)
local prop = property(StoreMgo)
prop:reader("primary_key", "")  -- primary_key

function StoreMgo:__init(sheet, primary_id)
end

function StoreMgo:load(key)
    self.primary_key = key
    local primary_id = self.primary_id
    local ok, code, data = mongo_agent:find_one({ self.sheet, { [key] = primary_id }}, primary_id)
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
    local ok, code, data = mongo_agent:delete({ self.sheet, { [self.primary_key] = primary_id }, true}, primary_id)
    if qfailed(code, ok) then
        log_err("[StoreMgo][load_{}] primary_id: {} find failed! code: {}, res: {}", self.sheet, primary_id, code, data)
    end
end

function StoreMgo:update_value(layers, key, value)
    Store.update_value(self, layers, key, value)
    store_mgr:save_wholes(self)
end

function StoreMgo:update_field(layers, field, key, value)
    Store.update_field(self, layers, field, key, value)
    store_mgr:save_wholes(self)
end

function StoreMgo:sync_whole()
    local primary_id = self.primary_id
    local primary_key = self.primary_key
    if not self.wholes[primary_key] then
        self.wholes[primary_key] = primary_id
    end
    local ok, code, adata = mongo_agent:update({ self.sheet, self.wholes, {[primary_key] = primary_id }, true}, primary_id)
    if qfailed(code, ok) then
        log_err("[StoreMgo][sync_whole] flush {}.{} failed! code: {}, res: {}", primary_id, self.sheet, code, adata)
    end
end

--注册驱动
store_mgr:bind_store("mongo", StoreMgo)
store_mgr:bind_driver("mongo", mongo_agent)

return StoreMgo
