--store_cache.lua
import("agent/mongo_agent.lua")
import("agent/cache_agent.lua")

local mmin          = math.min
local log_err       = logger.err
local log_debug     = logger.debug
local tinsert       = table.insert
local tconcat       = table.concat
local qfailed       = quanta.failed

local store_mgr     = quanta.get("store_mgr")
local cache_agent   = quanta.get("cache_agent")
local mongo_agent   = quanta.get("mongo_agent")

local Store         = import("store/store.lua")

local StoreCache = class(Store)

function StoreCache:__init(sheet, primary_id)
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

function StoreCache:update_value(layers, key, value)
    if self.wholes then
        Store.update_value(self, layers, key, value)
        return
    end
    log_debug("[StoreCache][update_value] {}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(layers, "."), key, value)
    tinsert(self.increases, {layers, value or "nil", key})
    store_mgr:save_increases(self)
end

function StoreCache:update_field(layers, field, key, value)
    if self.wholes then
        Store.update_field(self, layers, field, key, value)
        return
    end
    log_debug("[StoreCache][update_field] {}.{}.{}.{}.{}={}", self.primary_id, self.sheet, tconcat(layers, "."), field, key, value)
    tinsert(self.increases, { layers, value or "nil", key, field })
    store_mgr:save_increases(self)
end

function StoreCache:sync_increase()
    local commits = self:merge_commits()
    local code = cache_agent:update(self.primary_id, self.sheet, commits)
    if qfailed(code) then
        log_err("[StoreCache][sync_increase] update {}.{} failed! code: {}", self.primary_id, self.sheet, code)
        store_mgr:save_increases(self)
    end
end

function StoreCache:sync_whole()
    local code = cache_agent:flush(self.primary_id, self.sheet, self.wholes)
    if qfailed(code) then
        log_err("[StoreCache][sync_whole] flush {}.{} failed! code: {}", self.primary_id, self.sheet, code)
        store_mgr:save_wholes(self)
        return
    end
    self.wholes = nil
end

--内部方法
--------------------------------------------------------------
--判断commit是否increase的父节点或者本节点
local function is_parent_or_self(commit, inc_layers, inc_field)
    local clayers, cfield = commit[1], commit[4]
    local len1, len2 = #clayers, #inc_layers
    if len1 > len2 then
        return false
    end
    -- 比较前 n 个元素
    local mix = mmin(len1, len2)
    for i = 1, mix do
        -- 如果元素类型不同或值不同，返回 false
        if clayers[i] ~= inc_layers[i] then
            return false
        end
    end
    if len1 == len2 then
        return cfield == inc_field
    end
    return true
end

--倒序合并，cache也需要倒序读取
function StoreCache:merge_commits()
    local commits = {}
    --倒序遍历所有提交
    for i = #self.increases, 1, -1 do
        local increase = self.increases[i]
        --遍历已经合并的提交
        for _, commit in ipairs(commits) do
            --如果commit是increase的父节点或者本节点，则表示increase已经失效，需要丢弃
            if is_parent_or_self(commit, increase[1], increase[4]) then
                goto continue
            end
        end
        --开始提交
        tinsert(commits, increase)
        :: continue ::
    end
    self.increases = {}
    return commits
end

--注册驱动
store_mgr:bind_store("cache", StoreCache)
store_mgr:bind_driver("cache", mongo_agent)

return StoreCache
