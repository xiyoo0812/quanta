--game_dao.lua

import("store/db_property.lua")
import("agent/redis_agent.lua")
import("agent/mongo_agent.lua")
import("agent/cache_agent.lua")

local log_err       = logger.err
local log_debug     = logger.debug
local tsort         = table.sort
local tinsert       = table.insert
local qfailed       = quanta.failed
local makechan      = quanta.make_channel

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")
local config_mgr    = quanta.get("config_mgr")
local redis_agent   = quanta.get("redis_agent")
local cache_agent   = quanta.get("cache_agent")

local cache_db      = config_mgr:init_table("cache", "sheet")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local GameDAO = singleton()
local prop = property(GameDAO)
prop:reader("groups", {})           -- groups
prop:reader("recv_channel", nil)    -- recv_channel
prop:reader("send_channel", nil)    -- send_channel

function GameDAO:__init()
    cache_db:add_group("group")
    --通知监听
    update_mgr:attach_frame(self)
    --消息队列
    self.recv_channel = makechan("game dao")
    self.send_channel = makechan("game dao")
    --事件监听
    event_mgr:add_listener(self, "on_db_prop_update")
    event_mgr:add_listener(self, "on_db_prop_remove")
end

function GameDAO:find_group(group_name)
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

function GameDAO:load_impl(primary_id, sheet_name)
    local code, adata = cache_agent:load(primary_id, sheet_name)
    if qfailed(code) then
        log_err("[GameDAO][load_{}] primary_id: {} find failed! code: {}, res: {}", sheet_name, primary_id, code, adata)
        return false
    end
    return true, adata
end

function GameDAO:load(entity, primary_id, sheet_name)
    local ok, data = self:load_impl(primary_id, sheet_name)
    if not ok then
        return ok
    end
    entity["load_" .. sheet_name .. "_db"](entity, primary_id, data)
    return ok, SUCCESS
end

function GameDAO:load_group(entity, primary_id, group)
    local channel = makechan("load_group")
    local sheets = self:find_group(group)
    for _, conf in ipairs(sheets) do
        channel:push(function()
            local ok, data = self:load_impl(primary_id, conf.sheet)
            if not ok then
                return false, data
            end
            return ok, SUCCESS, data
        end)
    end
    local ok, cordatas = channel:execute()
    if not ok then
        return false
    end
    for i, conf in ipairs(sheets) do
        entity["load_" .. conf.sheet .. "_db"](entity, primary_id, cordatas[i])
    end
    return ok, SUCCESS
end

function GameDAO:update_field(primary_id, sheet_name, field, field_data)
    local code, adata = cache_agent:update_field(primary_id, sheet_name, field, field_data)
    if qfailed(code) then
        log_err("[GameDAO][update_field_{}] primary_id: {} find failed! code: {}, res: {}", sheet_name, primary_id, code, adata)
        return false
    end
    return true, SUCCESS
end

function GameDAO:remove_field(primary_id, sheet_name, field)
    local code, res = cache_agent:remove_field(primary_id, sheet_name, field)
    if qfailed(code) then
        log_err("[GameDAO][remove_field_{}] remove ({}) failed primary_id({}), code: {}, res: {}!", sheet_name, field, primary_id, code, res)
        return false
    end
    return true, SUCCESS
end

function GameDAO:delete(primary_id, sheet_name)
    self.recv_channel:push(function()
        local code, res = cache_agent:delete(primary_id, sheet_name)
        if qfailed(code) then
            log_err("[GameDAO][delete] delete ({}) failed primary_id({}), code: {}, res: {}!",  sheet_name, primary_id, code, res)
            return false
        end
        return true, SUCCESS
    end)
end

function GameDAO:on_db_prop_update(primary_id, sheet_name, db_key, value)
    log_debug("[GameDAO][on_db_prop_update] {} db_key: {}.{}", primary_id, sheet_name, db_key)
    self.recv_channel:push(function()
        return self:update_field(primary_id, sheet_name, db_key, value)
    end)
end

function GameDAO:on_db_prop_remove(primary_id, sheet_name, db_key)
    log_debug("[GameDAO][on_db_prop_remove] {} db_key: {}.{}", primary_id, sheet_name, db_key)
    self.recv_channel:push(function()
        return self:remove_field(primary_id, sheet_name, db_key)
    end)
end

function GameDAO:on_frame()
    if self.send_channel:empty() then
        local channel = self.send_channel
        self.send_channel = self.recv_channel
        self.recv_channel = channel
    end
    if self.send_channel:execute(true) then
        self.send_channel:clear()
    end
end

--redis通用接口
----------------------------------------------------------------------
function GameDAO:execute(primary_id, cmd, ...)
    local ok, code, result = redis_agent:execute({ cmd, ... }, primary_id)
    if qfailed(code, ok) then
        log_err("[GameDAO][execute] execute ({}) failed: code: {}, res: {}!",  cmd, code, result)
        return code
    end
    return code, result
end

quanta.game_dao = GameDAO()

return GameDAO
