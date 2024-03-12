--store_mdb.lua
local log_err       = logger.err
local log_debug     = logger.debug
local tconcat       = table.concat
local qtweak        = qtable.weak

local mdb_driver    = quanta.get("mdb_driver")
local store_mgr     = quanta.get("store_mgr")

local StoreMdb = class()
local prop = property(StoreMdb)
prop:reader("sheet", "")        -- sheet
prop:reader("primary_id", "")   -- primary_id
prop:reader("primary_key", "")   -- primary_key
prop:reader("targets", nil)

function StoreMdb:__init(sheet, primary_id)
    self.sheet = sheet
    self.primary_id = primary_id
end

function StoreMdb:bind_target(obj)
    self.targets = qtweak({})
    self.targets[obj] = true
end

function StoreMdb:load(key)
    self.primary_key = key
    local data, ok = mdb_driver:get(self.primary_id, self.sheet)
    if not ok then
        return false
    end
    self.wholes = data or {}
    return true, self.wholes
end

function StoreMdb:flush(obj, timely)
    self.wholes = obj["serialize_" .. self.sheet](obj)
    if timely then
        self:sync_whole()
    else
        store_mgr:save_wholes(self)
    end
end

function StoreMdb:update_value(parentkeys, key, value)
    log_debug("[StoreMdb][update_value] {}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(parentkeys, "."), key, value)
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

function StoreMdb:update_field(parentkeys, field, key, value)
    log_debug("[StoreMdb][update_field] {}.{}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(parentkeys, "."), field, key, value)
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

function StoreMdb:sync_increase()
end

function StoreMdb:sync_whole()
    if not self.wholes[self.primary_key] then
        self.wholes[self.primary_key] = self.primary_id
    end
    log_debug("[StoreMdb][sync_whole] {}.{}={}", self.primary_id, self.sheet, self.wholes)
    if not mdb_driver:put(self.primary_id, self.wholes, self.sheet) then
        log_err("[StoreMdb][sync_whole] sync {}.{} failed!", self.primary_id, self.sheet)
    end
end

return StoreMdb
