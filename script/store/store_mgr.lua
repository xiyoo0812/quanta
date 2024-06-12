--store_mgr.lua

import("store/db_property.lua")

import("agent/cache_agent.lua")
import("agent/redis_agent.lua")

local log_err       = logger.err
local tsort         = table.sort
local tinsert       = table.insert
local qfailed       = quanta.failed
local makechan      = quanta.make_channel

local update_mgr    = quanta.get("update_mgr")
local config_mgr    = quanta.get("config_mgr")
local cache_agent   = quanta.get("cache_agent")
local redis_agent   = quanta.get("redis_agent")

local cache_db      = config_mgr:init_table("cache", "sheet")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local STORE_INCRE   = environ.number("QUANTA_STORE_FLUSH")

local STORE_WHOLE   = STORE_INCRE // 10

local StoreMgr = singleton()
local prop = property(StoreMgr)
prop:reader("groups", {})       -- groups
prop:reader("wholes", {})       -- wholes
prop:reader("driver", nil)      -- driver
prop:reader("increases", {})    -- increases

function StoreMgr:__init()
    cache_db:add_group("group")
    --通知监听
    update_mgr:attach_fast(self)
    update_mgr:attach_second(self)
end

function StoreMgr:open(driver, name, dbname)
    if not self.driver then
        driver:open(name, dbname)
        self.driver = driver
    end
end

function StoreMgr:find_group(group_name)
    local sgroup = self.groups[group_name]
    if sgroup then
        return sgroup
    end
    sgroup = {}
    for _, sconf in pairs(cache_db:find_group(group_name)) do
        if not sconf.inertable then
            tinsert(sgroup, sconf)
        end
    end
    tsort(sgroup, function(a, b) return a.id < b.id end)
    self.groups[group_name] = sgroup
    return sgroup
end

function StoreMgr:get_autoinc_id(character_id, world_id)
    if self.driver then
        local aok, role_id = self.driver:autoinc_id()
        if not aok then
            log_err("[CharacterWorld][get_autoinc_id] failed: character_id: {} world_id:{} res: {}", character_id, world_id, role_id)
            return false
        end
        return true, role_id
    end
    local aok, acode, role_id = redis_agent:autoinc_id()
    if qfailed(acode, aok) then
        log_err("[CharacterWorld][get_autoinc_id] failed: character_id: {} world_id:{} code: {}, res: {}", character_id, world_id, acode, role_id)
        return false
    end
    return true, role_id
end

function StoreMgr:load_impl(primary_id, sheet_name)
    if self.driver then
        local primary_key = cache_db:find_value("key", sheet_name)
        local StoreKV = import("store/store_kv.lua")
        local store = StoreKV(self.driver, sheet_name, primary_id)
        local ok, adata = store:load(primary_key)
        if not ok then
            log_err("[StoreMgr][load_mdb_{}] primary_id: {} find failed! res: {}", sheet_name, primary_id, adata)
            return false
        end
        return true, adata, store
    end
    local code, adata = cache_agent:load(primary_id, sheet_name)
    if qfailed(code) then
        log_err("[StoreMgr][load_{}] primary_id: {} find failed! code: {}, res: {}", sheet_name, primary_id, code, adata)
        return false
    end
    local Store = import("store/store.lua")
    local store = Store(sheet_name, primary_id)
    return true, adata, store
end

function StoreMgr:load(entity, primary_id, sheet_name)
    local ok, data, store = self:load_impl(primary_id, sheet_name)
    if not ok then
        return ok, data
    end
    local func = entity["load_" .. sheet_name .. "_db"]
    local ok2, err = pcall(func, entity, store, data)
    if not ok2 then
        log_err("[StoreMgr][load] load ({}) failed primary_id({}), err: {}!",  sheet_name, primary_id, err)
        return ok2, err
    end
    return ok, SUCCESS, data
end

function StoreMgr:load_group(entity, primary_id, group)
    local channel = makechan("load_group")
    local sheets = self:find_group(group)
    for _, conf in ipairs(sheets) do
        channel:push(function()
            return self:load(entity, primary_id, conf.sheet)
        end)
    end
    if not channel:execute(true) then
        return false
    end
    return true, SUCCESS
end

function StoreMgr:delete(primary_id, sheet_name)
    local code, res = cache_agent:delete(primary_id, sheet_name)
    if qfailed(code) then
        log_err("[StoreMgr][delete] delete ({}) failed primary_id({}), code: {}, res: {}!",  sheet_name, primary_id, code, res)
        return false
    end
    return true, SUCCESS
end

function StoreMgr:save_wholes(store)
    self.wholes[store] = true
end

function StoreMgr:save_increases(store)
    self.increases[store] = true
end

function StoreMgr:on_fast()
    local channel = makechan("increases store")
    for store in pairs(self.increases) do
        self.increases[store] = nil
        channel:push(function()
            store:sync_increase()
        end)
        if channel:isfull(STORE_INCRE) then
            break
        end
    end
    channel:execute(true)
end

function StoreMgr:on_second()
    local channel = makechan("increases store")
    for store in pairs(self.wholes) do
        self.wholes[store] = nil
        channel:push(function()
            store:sync_whole()
        end)
        if channel:isfull(STORE_WHOLE) then
            break
        end
    end
    channel:execute(true)
end

quanta.store_mgr = StoreMgr()

return StoreMgr
