--store.lua
local log_err       = logger.err
local log_debug     = logger.debug
local tinsert       = table.insert
local tconcat       = table.concat
local tunpack       = table.unpack
local tremove       = table.remove
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

function Store:flush(obj)
    self.increases = {}
    store_mgr:save_wholes(self)
    self.wholes = obj["serialize_" .. self.sheet](obj)
    log_debug("[Store][flush] {}.{}={}", self.primary_id, self.sheet, self.wholes)
end

function Store:update_value(parentkeys, key, value)
    log_debug("[Store][update_value] {}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(parentkeys, "."), key, value)
    if not self.wholes then
        tinsert(self.increases, {parentkeys, value, key})
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
        tinsert(self.increases, {parentkeys, value, key, field })
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

local function clean_repeat(commits, parents, field)
    for i = #commits, 1, -1 do
        local info = commits[i]
        if info[4] and info[1] == parents and info[2] == field then
            tremove(commits, i)
        end
    end
end

function Store:build_commits()
    local commits = {}
    local cvalues, lastkeys, lastfield = {}, nil, nil
    for _, increase in ipairs(self.increases) do
        local parents, value, key, field = tunpack(increase)
        if not key then
            if lastkeys then
                tinsert(commits, { lastkeys, lastfield, cvalues })
            end
            --清理重复
            clean_repeat(commits, parents, field)
            --全量更新
            tinsert(commits, { parents, field, value or "nil", true })
            cvalues, lastkeys, lastfield = {}, nil, nil
            goto continue
        end
        if lastkeys and (lastkeys ~= parents or lastfield ~= field) then
            tinsert(commits, { lastkeys, lastfield, cvalues })
            cvalues = {}
        end
        lastkeys, lastfield = parents, field
        cvalues[key] = value or "nil"
        :: continue ::
    end
    if lastkeys then
        tinsert(commits, { lastkeys, lastfield, cvalues })
    end
    self.increases = {}
    return commits
end

function Store:sync_increase(channel)
    if self.wholes then
        return
    end
    local commits = self:build_commits()
    channel:push(function()
        local code, adata = cache_agent:update(self.primary_id, self.sheet, commits)
        if qfailed(code) then
            log_err("[StoreMgr][sync_increase] update {}.{} failed! code: {}, res: {}", self.primary_id, self.sheet, code, adata)
            for obj in pairs(self.targets) do
                self:flush(obj)
            end
            return false
        end
        return true, SUCCESS
    end)
end

function Store:sync_whole(channel)
    if not self.wholes then
        return
    end
    channel:push(function()
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
    end)
end

return Store
