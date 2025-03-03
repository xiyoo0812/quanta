--store.lua
local log_dump      = logger.dump
local log_debug     = logger.debug
local tconcat       = table.concat

local store_mgr     = quanta.get("store_mgr")

local Store = class()
local prop = property(Store)
prop:reader("sheet", "")        -- sheet
prop:reader("wholes", nil)      -- wholes
prop:reader("increases", {})    -- increases
prop:reader("primary_id", "")   -- primary_id

function Store:__init(sheet, primary_id)
    self.sheet = sheet
    self.primary_id = primary_id
end

function Store:load(key)
    return false
end

function Store:delete()
end

function Store:flush(obj, timely)
    self.wholes = obj["serialize_" .. self.sheet](obj)
    if timely then
        self:sync_whole()
    else
        store_mgr:save_wholes(self)
    end
    log_debug("[Store][flush] {}.{}={}", self.primary_id, self.sheet, self.wholes)
end

function Store:update_value(layers, key, value)
    log_dump("[Store][update_value] {}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(layers, "."), key, value)
    local cur_data = self.wholes
    for _, cfield in ipairs(layers) do
        if not cur_data[cfield] then
            cur_data[cfield] = {}
        end
        cur_data = cur_data[cfield]
    end
    cur_data[key] = value
end

function Store:update_field(layers, field, key, value)
    log_dump("[Store][update_field] {}.{}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(layers, "."), field, key, value)
    local cur_data = self.wholes
    for _, cfield in ipairs(layers) do
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
        return
    end
    --key为空，全量更新
    cur_data[field] = value
end

function Store:sync_increase()
end

function Store:sync_whole()
end

return Store
