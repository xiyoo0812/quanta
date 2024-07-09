--store_cache.lua
import("agent/mongo_agent.lua")
import("agent/cache_agent.lua")

local log_err       = logger.err
local log_debug     = logger.debug
local tinsert       = table.insert
local tconcat       = table.concat
local tunpack       = table.unpack
local qfailed       = quanta.failed
local qtweak        = qtable.weak

local store_mgr     = quanta.get("store_mgr")
local cache_agent   = quanta.get("cache_agent")
local mongo_agent   = quanta.get("mongo_agent")

local Store         = import("store/store.lua")

local StoreCache = class(Store)
local prop = property(StoreCache)
prop:reader("targets", nil)

function StoreCache:__init(sheet, primary_id)
end

function StoreCache:bind_target(obj)
    self.targets = qtweak({})
    self.targets[obj] = true
end

function StoreCache:load(key)
    local code, data = cache_agent:load(self.primary_id, self.sheet)
    if qfailed(code) then
        log_err("[StoreMgr][load_{}] primary_id: {} find failed! code: {}, res: {}", self.sheet, self.primary_id, code, data)
        return false
    end
    return true, data
end

function StoreCache:delete()
    self.wholes = nil
    local code = cache_agent:delete(self.primary_id, self.sheet)
    if qfailed(code) then
        log_err("[StoreMgo][delete_{}] primary_id: {} delete failed! code: {}", self.sheet, self.primary_id, code)
    end
end

function StoreCache:flush(obj, timely)
    self.increases = {}
    Store.flush(self, obj, timely)
end

function StoreCache:update_value(parentkeys, key, value)
    if self.wholes then
        Store.update_value(self, parentkeys, key, value)
        return
    end
    log_debug("[StoreCache][update_value] {}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(parentkeys, "."), key, value)
    tinsert(self.increases, {parentkeys, value or "nil", key})
    store_mgr:save_increases(self)
end

function StoreCache:update_field(parentkeys, field, key, value)
    if self.wholes then
        Store.update_field(self, parentkeys, field, key, value)
        return
    end
    log_debug("[StoreCache][update_field] {}.{}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(parentkeys, "."), field, key, value)
    tinsert(self.increases, {parentkeys, value or "nil", key, field })
    store_mgr:save_increases(self)
end

function StoreCache:sync_increase()
    local commits = self:merge_commits()
    local code = cache_agent:update(self.primary_id, self.sheet, commits)
    if qfailed(code) then
        log_err("[StoreCache][sync_increase] update {}.{} failed! code: {}", self.primary_id, self.sheet, code)
        for obj in pairs(self.targets) do
            self:flush(obj)
        end
    end
end

function StoreCache:sync_whole()
    local code = cache_agent:flush(self.primary_id, self.sheet, self.wholes)
    if qfailed(code) then
        log_err("[StoreCache][sync_whole] flush {}.{} failed! code: {}", self.primary_id, self.sheet, code)
        for obj in pairs(self.targets) do
            self:flush(obj)
        end
        return
    end
    self.wholes = nil
end

--内部方法
--------------------------------------------------------------
function StoreCache:can_merge(increase, commit)
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

function StoreCache:alike(increase, commit)
    local max = #increase > #commit and #increase or #commit
    for i = 1, max do
        if increase[i] and commit[i] and increase[i] ~= commit[i] then
            return false
        end
    end
    return true
end

function StoreCache:break_merge(increase, commit)
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

function StoreCache:merge_commits()
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

--注册驱动
store_mgr:bind_store("cache", StoreCache)
store_mgr:bind_driver("cache", mongo_agent)

return StoreCache
