--login.lua

local log_err       = logger.err
local qfailed       = quanta.failed

local game_dao      = quanta.get("game_dao")
local mongo_agent   = quanta.get("mongo_agent")

local LoginDao = singleton()

function LoginDao:__init()
    game_dao:add_sheet(nil, "account", "open_id", { account = 1})
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

function LoginDao:create_player(player_id, data)
    local pdata = { nick = data.name, gender = data.gender, facade = data.custom, create_time = quanta.now }
    local ok, code, udata = mongo_agent:insert({ "player", { player = pdata, player_id = player_id } })
    if qfailed(code, ok) then
        log_err("[LoginDao][create_player] player_id: %s create failed! code: %s, res: %s", player_id, code, udata)
        return false
    end
    return true
end

quanta.login_dao = LoginDao()

return LoginDao
