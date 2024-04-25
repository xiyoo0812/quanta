--store_kv.lua
local log_err       = logger.err
local log_debug     = logger.debug
local tconcat       = table.concat
local qtweak        = qtable.weak

local store_mgr     = quanta.get("store_mgr")

local StoreKV = class()
local prop = property(StoreKV)
prop:reader("sheet", "")        -- sheet
prop:reader("driver", nil)      -- driver
prop:reader("primary_id", "")   -- primary_id
prop:reader("primary_key", "")  -- primary_key
prop:reader("targets", nil)

function StoreKV:__init(driver, sheet, primary_id)
    self.sheet = sheet
    self.driver = driver
    self.primary_id = primary_id
end

function StoreKV:bind_target(obj)
    self.targets = qtweak({})
    self.targets[obj] = true
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

function StoreKV:flush(obj, timely)
    self.wholes = obj["serialize_" .. self.sheet](obj)
    if timely then
        self:sync_whole()
    else
        store_mgr:save_wholes(self)
    end
end

function StoreKV:update_value(parentkeys, key, value)
    log_debug("[StoreKV][update_value] {}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(parentkeys, "."), key, value)
    local cur_data = self.wholes
    for _, cfield in ipairs(parentkeys) do
        if not cur_data[cfield] then
            cur_data[cfield] = {}
        end
        cur_data = cur_data[cfield]
    end
    cur_data[key] = value
    store_mgr:save_wholes(self)
end

function StoreKV:update_field(parentkeys, field, key, value)
    log_debug("[StoreKV][update_field] {}.{}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(parentkeys, "."), field, key, value)
    local cur_data = self.wholes
    for _, cfield in ipairs(parentkeys) do
        if not cur_data[cfield] then
            cur_data[cfield] = {}
        end
        cur_data = cur_data[cfield]
    end
    if not cur_data[field] then
        cur_data[field] = {}
    end
    if key then
        cur_data[field][key] = value
    else
        --key为空，全量更新
        cur_data[field] = value
    end
    store_mgr:save_wholes(self)
end

function StoreKV:sync_increase()
end

function StoreKV:sync_whole()
    if not self.wholes[self.primary_key] then
        self.wholes[self.primary_key] = self.primary_id
    end
    log_debug("[StoreKV][sync_whole] {}.{}={}", self.primary_id, self.sheet, self.wholes)
    if not self.driver:put(self.primary_id, self.wholes, self.sheet) then
        log_err("[StoreKV][sync_whole] sync {}.{} failed!", self.primary_id, self.sheet)
    end
end

return StoreKV
