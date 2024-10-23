--store_mgr.lua

local log_err       = logger.err
local log_debug     = logger.debug
local tsort         = table.sort
local tinsert       = table.insert
local qfailed       = quanta.failed
local makechan      = quanta.make_channel

local update_mgr    = quanta.get("update_mgr")
local config_mgr    = quanta.get("config_mgr")

local cache_db      = config_mgr:init_table("cache", "sheet")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local STORE_INCRE   = environ.number("QUANTA_STORE_FLUSH")
local QUANTA_STORE  = environ.get("QUANTA_STORE")

local STORE_WHOLE   = STORE_INCRE // 10

local StoreMgr = singleton()
local prop = property(StoreMgr)
prop:reader("driver", nil)      -- cur driver
prop:reader("groups", {})       -- groups
prop:reader("wholes", {})       -- wholes
prop:reader("increases", {})    -- increases
prop:reader("db_stores", {})    -- db_stores
prop:reader("db_drivers", {})   -- db_drivers

function StoreMgr:__init()
    cache_db:add_group("group")
    --通知监听
    update_mgr:attach_quit(self)
    update_mgr:attach_fast(self)
    update_mgr:attach_second(self)
end

function StoreMgr:on_quit()
    update_mgr:detach_fast(self)
    update_mgr:detach_second(self)
end

function StoreMgr:open_driver(name, dbname)
    local driver = self.db_drivers[QUANTA_STORE]
    if driver then
        driver:open(name, dbname)
        self.driver = driver
    end
end

function StoreMgr:bind_driver(name, store)
    self.db_drivers[name] = store
    log_debug("[StoreMgr][bind_driver] name: {}", name)
end

function StoreMgr:bind_store(name, store)
    self.db_stores[name] = store
    log_debug("[StoreMgr][bind_store] name: {}", name)
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

function StoreMgr:get_autoinc_id()
    local driver = self.db_drivers[QUANTA_STORE]
    if driver then
        local ok, code, role_id = driver:autoinc_id()
        if qfailed(code, ok) then
            log_err("[StoreMgr][get_autoinc_id] failed: res: {}", role_id)
            return false
        end
        return true, role_id
    end
    return false
end

function StoreMgr:load_impl(primary_id, sheet_name)
    local primary_key = cache_db:find_value("key", sheet_name)
    local Store = self.db_stores[QUANTA_STORE]
    if not Store then
        log_err("[StoreMgr][load_impl] store {} not register!", QUANTA_STORE)
        return false
    end
    local store = Store(sheet_name, primary_id)
    local ok, adata = store:load(primary_key)
    if not ok then
        log_err("[StoreMgr][load_impl_{}] primary_id: {} find failed! res: {}", sheet_name, primary_id, adata)
        return false
    end
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

function StoreMgr:delete_group(entity, primary_id, group)
    local channel = makechan("delete_group")
    local sheets = self:find_group(group)
    for _, conf in ipairs(sheets) do
        channel:push(function()
            return self:delete(entity, primary_id, conf.sheet)
        end)
    end
    if not channel:execute(true) then
        return false
    end
    return true, SUCCESS
end

function StoreMgr:delete(entity, primary_id, sheet_name)
    local func = entity["delete_" .. sheet_name .. "_db"]
    local ok, err = pcall(func, entity, self)
    if not ok then
        log_err("[StoreMgr][delete] delete ({}) failed primary_id({}), err: {}!",  sheet_name, primary_id, err)
        return ok, err
    end
    return ok, SUCCESS
end

function StoreMgr:clean_store(store)
    self.increases[store] = nil
    self.wholes[store] = nil
end

function StoreMgr:save_wholes(store)
    self.wholes[store] = true
end

function StoreMgr:save_increases(store)
    self.increases[store] = true
end

function StoreMgr:on_fast()
    if not next(self.increases) then
        return
    end
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
    if not next(self.wholes) then
        return
    end
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
