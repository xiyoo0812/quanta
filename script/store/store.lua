--store.lua
local log_err       = logger.err
local log_debug     = logger.debug
local tinsert       = table.insert
local tconcat       = table.concat
local tunpack       = table.unpack
local qfailed       = quanta.failed
local qtweak        = qtable.weak

local store_mgr     = quanta.get("store_mgr")
local cache_agent   = quanta.get("cache_agent")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local Store = class()
local prop = property(Store)
prop:reader("sheet", "")        -- sheet
prop:reader("wholes", nil)      -- wholes
prop:reader("increases", {})    -- increases
prop:reader("primary_id", "")   -- primary_id
prop:reader("targets", nil)

function Store:__init(sheet, primary_id)
    self.sheet = sheet
    self.primary_id = primary_id
end

function Store:bind_target(obj)
    self.targets = qtweak({})
    self.targets[obj] = true
end

function Store:flush(obj, timely)
    self.increases = {}
    self.wholes = obj["serialize_" .. self.sheet](obj)
    if timely then
        self:sync_whole()
    else
        store_mgr:save_wholes(self)
    end
    log_debug("[Store][flush] {}.{}={}", self.primary_id, self.sheet, self.wholes)
end

function Store:update_value(parentkeys, key, value)
    log_debug("[Store][update_value] {}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(parentkeys, "."), key, value)
    if not self.wholes then
        tinsert(self.increases, {parentkeys, value or "nil", key})
        store_mgr:save_increases(self)
        return
    end
    local cur_data = self.wholes
    for _, cfield in ipairs(parentkeys) do
        if not cur_data[cfield] then
            cur_data[cfield] = {}
        end
        cur_data = cur_data[cfield]
    end
    cur_data[key] = value
end

function Store:update_field(parentkeys, field, key, value)
    log_debug("[Store][update_field] {}.{}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(parentkeys, "."), field, key, value)
    if not self.wholes then
        tinsert(self.increases, {parentkeys, value or "nil", key, field })
        store_mgr:save_increases(self)
        return
    end
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
        return
    end
    --key为空，全量更新
    cur_data[field] = value
end

function Store:can_merge(increase, commit)
    --parents
    if increase[1] ~= commit[1] then
        return false
    end
    --field
    if increase[4] ~= commit[2]  then
        return false
    end
    return true
end

function Store:alike(increase, commit)
    local max = #increase > #commit and #increase or #commit
    for i = 1, max do
        if increase[i] and commit[i] and increase[i] ~= commit[i] then
            return false
        end
    end
    return true
end

function Store:break_merge(increase, commit)
    if self:alike(increase[1], commit[1]) then
        if #increase[1] ~= #commit[1] then
            return true
        end
        if increase[4] ~= commit[2]  then
            return true
        end
    end
    return false
end

function Store:merge_commits()
    local commits = {}
    for _, increase in ipairs(self.increases) do
        local parents, value, key, field = tunpack(increase)
        for i = #commits, 1, -1 do
            local commit = commits[i]
            if self:break_merge(increase, commit) then
                break
            end
            if self:can_merge(increase, commit) then
                if commit[3] == "nil" then
                    commit[3] = key and {[key] = value } or value
                    goto continue
                end
                if key then
                    commit[3][key] = value
                    goto continue
                end
                commit[3] = value
                commit[4] = true
                goto continue
            end
        end
        tinsert(commits, { parents, field,  key and {[key] = value } or value, (key == nil) and true or nil })
        :: continue ::
    end
    self.increases = {}
    return commits
end

function Store:sync_increase()
    local commits = self:merge_commits()
    local code, adata = cache_agent:update(self.primary_id, self.sheet, commits)
    if qfailed(code) then
        log_err("[StoreMgr][sync_increase] update {}.{} failed! code: {}, res: {}", self.primary_id, self.sheet, code, adata)
        for obj in pairs(self.targets) do
            self:flush(obj)
        end
        return false
    end
    return true, SUCCESS
end

function Store:sync_whole()
    local code, adata = cache_agent:flush(self.primary_id, self.sheet, self.wholes)
    if qfailed(code) then
        log_err("[StoreMgr][sync_whole] flush {}.{} failed! code: {}, res: {}", self.primary_id, self.sheet, code, adata)
        for obj in pairs(self.targets) do
            self:flush(obj)
        end
        return false
    end
    self.wholes = nil
    return true, SUCCESS
end

return Store
