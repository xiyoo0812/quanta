--store.lua
local qmerge    = qtable.merge
local tconcat   = table.concat
local log_debug = logger.debug

local store_mgr = quanta.get("store_mgr")

local Store = class()
local prop = property(Store)
prop:reader("sheet", "")        -- sheet
prop:reader("datas", {})        -- datas
prop:reader("primary_id", "")   -- primary_id

function Store:__init(sheet, primary_id)
    self.sheet = sheet
    self.primary_id = primary_id
end

function Store:update(value)
    self.datas = value
    store_mgr:save_store(self, true)
    log_debug("[Store][update] {}.{}={}", self.primary_id, self.sheet, value)
end

function Store:update_value(parentkeys, key, value)
    local cur_data = self.datas
    for _, cfield in ipairs(parentkeys) do
        if not cur_data[cfield] then
            cur_data[cfield] = {}
        end
        cur_data = cur_data[cfield]
    end
    cur_data[key] = value or "null"
    store_mgr:save_store(self, false)
    log_debug("[Store][update_value] {}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(parentkeys, "."), key, value)
end

function Store:update_field(parentkeys, field, key, value)
    local cur_data = self.datas
    for _, cfield in ipairs(parentkeys) do
        if not cur_data[cfield] then
            cur_data[cfield] = {}
        end
        cur_data = cur_data[cfield]
    end
    if not cur_data[field] then
        cur_data[field] = {}
    end
    cur_data[field][key] = value or "null"
    store_mgr:save_store(self, false)
    log_debug("[Store][update_field] {}.{}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(parentkeys, "."), field, key, value)
end

function Store:load_datas()
    local datas = self.datas
    self.datas = {}
    return datas
end

function Store:merge_datas(odatas)
    local ndatas = self.datas
    self.datas = qmerge(odatas, ndatas)
end

return Store
