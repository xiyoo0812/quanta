--game_dao.lua
import("store/db_property.lua")
import("agent/mongo_agent.lua")
import("agent/cache_agent.lua")

local log_err       = logger.err
local tunpack       = table.unpack
local tinsert       = table.insert
local qfailed       = quanta.failed

local mongo_agent   = quanta.get("mongo_agent")
local cache_agent   = quanta.get("cache_agent")

local USE_CACHE     = environ.status("QUANTA_DB_USE_CACHE")

local GameDAO = class()
local prop = property(GameDAO)
prop:reader("group", "game")
prop:reader("sheets", {})
prop:reader("sheet_indexs", {})

function GameDAO:__init()
end

--{ "entity", "role_id", { _id = 0 } },
function GameDAO:add_sheet(index, sheet_name, primary_key, filters)
    if not self.sheet_indexs[sheet_name] then
        self.sheet_indexs[sheet_name] = { primary_key, filters or { _id = 0 } }
        if index then
            tinsert(self.sheets, sheet_name)
        end
    end
end

function GameDAO:load(primary_id, sheet_name)
    if USE_CACHE then
        local primary_key, filters = self:find_primary_key(sheet_name)
        if not primary_key then
            return false
        end
        local ok, code, adata = cache_agent:load(primary_id, sheet_name, primary_key, filters, self.group)
        if qfailed(code, ok) then
            log_err("[GameDAO][load_%s] primary_id: %s find failed! code: %s, res: %s", sheet_name, primary_id, code, adata)
            return false
        end
        return true, adata
    end
    return self:load_mongo(primary_id, sheet_name)
end

function GameDAO:load_mongo(primary_id, sheet_name)
    local primary_key, filters = self:find_primary_key(sheet_name)
    if not primary_key then
        return false
    end
    local ok, code, adata = mongo_agent:find_one({ sheet_name, { [primary_key] = primary_id }, filters })
    if qfailed(code, ok) then
        log_err("[GameDAO][load_mongo_%s] primary_id: %s find failed! code: %s, res: %s", sheet_name, primary_id, code, adata)
        return false
    end
    return true, adata
end

function GameDAO:load_all(entity, primary_id)
    for _, sheet_name in ipairs(self.sheets) do
        local function load_sheet_db()
            return self:load(primary_id, sheet_name)
        end
        local ok = entity["load_" .. sheet_name .. "_db"](entity, primary_id, load_sheet_db)
        if not ok then
            return false
        end
    end
    return true
end

function GameDAO:update_field(primary_id, sheet_name, field, field_data, flush)
    if USE_CACHE then
        local primary_key = self:find_primary_key(sheet_name)
        if not primary_key then
            return false
        end
        local ok, code, adata = cache_agent:update_field(primary_id, sheet_name, primary_key, field, field_data, flush)
        if qfailed(code, ok) then
            log_err("[GameDAO][update_field_%s] primary_id: %s find failed! code: %s, res: %s", sheet_name, primary_id, code, adata)
            return false
        end
        return true
    end
    return self:update_mongo_field(primary_id, sheet_name, field, field_data)
end

function GameDAO:update_mongo_field(primary_id, sheet_name, field, field_data)
    local primary_key = self:find_primary_key(sheet_name)
    if not primary_key then
        return false
    end
    local udata = { ["$set"] = { [field] = field_data } }
    local ok, code, res = mongo_agent:update({ sheet_name, udata, { [primary_key] = primary_id }, true })
    if qfailed(code, ok) then
        log_err("[GameDAO][update_mongo_field%s] update (%s) failed! primary_id(%s), code(%s), res(%s)", sheet_name, field, primary_id, code, res)
        return false
    end
    return true
end

function GameDAO:remove_field(primary_id, sheet_name, field, flush)
    if USE_CACHE then
        local primary_key = self:find_primary_key(sheet_name)
        if not primary_key then
            return false
        end
        local ok, code, res = cache_agent:remove_field(primary_id, sheet_name, primary_key, field, flush)
        if qfailed(code, ok) then
            log_err("[GameDAO][remove_field_%s] remove (%s) failed primary_id(%s), code: %s, res: %s!", sheet_name, field, primary_id, code, res)
            return false
        end
        return true
    end
    return self:remove_mongo_field(primary_id, sheet_name, field)
end

function GameDAO:remove_mongo_field(primary_id, sheet_name, field)
    local primary_key = self:find_primary_key(sheet_name)
    if not primary_key then
        return false
    end
    local udata = { ["$unset"] = { [field] = 1 } }
    local ok, code, res = mongo_agent:update({ sheet_name, udata, { [primary_key] = primary_id }, true })
    if qfailed(code, ok) then
        log_err("[GameDAO][remove_field_%s] remove (%s) failed primary_id(%s), code: %s, res: %s!", sheet_name, field, primary_id, code, res)
        return false
    end
    return true
end

function GameDAO:delete(primary_id, sheet_name)
    if USE_CACHE then
        local primary_key = self:find_primary_key(sheet_name)
        if not primary_key then
            return false
        end
        local ok, code, res = cache_agent:delete(primary_id, sheet_name, primary_key, self.group)
        if qfailed(code, ok) then
            log_err("[GameDAO][delete] delete (%s) failed primary_id(%s), code: %s, res: %s!",  sheet_name, primary_id, code, res)
            return false
        end
    end
    return self:delete_mongo(primary_id, sheet_name)
end

function GameDAO:delete_mongo(primary_id, sheet_name)
    local primary_key = self:find_primary_key(sheet_name)
    if not primary_key then
        return false
    end
    local ok, code, res = mongo_agent:delete({ sheet_name, { [primary_key] = primary_id }, true })
    if qfailed(code, ok) then
        log_err("[GameDAO][delete_mongo_%s] delete failed primary_id(%s), code: %s, res: %s!", sheet_name, primary_id, code, res)
        return false
    end
    return true
end

function GameDAO:flush(primary_id)
    if USE_CACHE then
        local ok, code, res = cache_agent:flush(primary_id, self.group)
        if qfailed(code, ok) then
            log_err("[GameDAO][flush] flush (%s) failed primary_id(%s), code: %s, res: %s!",  primary_id, code, res)
            return false
        end
    end
    return true
end

function GameDAO:find_primary_key(sheet_name)
    local sheet = self.sheet_indexs[sheet_name]
    if not sheet then
        log_err("[GameDAO][find_primary_key] sheet %s not defined primary_key!", sheet_name)
        return false
    end
    return tunpack(sheet)
end

return GameDAO
