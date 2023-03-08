--login.lua

local log_err       = logger.err
local log_info      = logger.info
local qfailed       = quanta.failed

local GameDAO       = import("store/game_dao.lua")

local event_mgr     = quanta.get("event_mgr")
local mongo_agent   = quanta.get("mongo_agent")

local LoginDao = singleton(GameDAO)

function LoginDao:__init()
    event_mgr:add_listener(self, "on_db_prop_update")
    event_mgr:add_listener(self, "on_db_prop_remove")
    self:add_sheet(false, "account", "open_id", { account = 1})
end

function LoginDao:on_db_prop_update(primary_id, sheet_name, db_key, value)
    log_info("[LoginDao][on_db_prop_update] primary_id: %s sheet_name: %s, db_key: %s", primary_id, sheet_name, db_key)
    return self:update_field(primary_id, sheet_name, db_key, value, true)
end

function LoginDao:on_db_prop_remove(primary_id, sheet_name, db_key)
    log_info("[LoginDao][on_db_prop_remove] primary_id: %s sheet_name: %s, db_key: %s", primary_id, sheet_name, db_key)
    return self:remove_field(primary_id, sheet_name, db_key, true)
end

function LoginDao:get_autoinc_id(open_id)
    local aok, acode, role_id = mongo_agent:get_autoinc_id("player")
    if qfailed(acode, aok) then
        log_err("[LoginDao][create_player] open_id: %s get_autoinc_id failed! code: %s, res: %s", open_id, acode, role_id)
        return
    end
    return role_id
end

function LoginDao:check_name_exist(name)
    local ok, code, udata = mongo_agent:find_one({ "player", { name = name } })
    if qfailed(code, ok) then
        log_err("[LoginDao][check_name_exist] name: %s find failed! code: %s, res: %s", name, code, udata)
        return false
    end
    return udata
end

function LoginDao:create_player(player_id, pdata)
    local ok, code, udata = mongo_agent:insert({ "player", { player = pdata, player_id = player_id } })
    if qfailed(code, ok) then
        log_err("[LoginDao][create_player] player_id: %s create failed! code: %s, res: %s", player_id, code, udata)
        return false
    end
    return true
end

quanta.login_dao = LoginDao()

return LoginDao
