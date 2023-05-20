--login.lua

local log_err       = logger.err
local tunpack       = table.unpack
local qfailed       = quanta.failed
local qconverger    = quanta.make_converger

local game_dao      = quanta.get("game_dao")
local event_mgr     = quanta.get("event_mgr")
local mongo_agent   = quanta.get("mongo_agent")
local redis_agent   = quanta.get("redis_agent")

local BENCHMARK     = environ.number("QUANTA_DB_BENCHMARK")
local AUTOINCKEY    = environ.get("QUANTA_DB_AUTOINCKEY", "COUNTER:QUANTA:ROLE")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local LoginDao = singleton()

function LoginDao:__init()
    game_dao:add_sheet("account", "account", "open_id")
end

function LoginDao:get_autoinc_id(user_id)
    local aok, acode, role_id = redis_agent:execute({ "INCR", AUTOINCKEY })
    if qfailed(acode, aok) then
        log_err("[LoginDao][get_autoinc_id] user_id: %s get_autoinc_id failed! code: %s, res: %s", user_id, acode, role_id)
        return false
    end
    return true, SUCCESS, BENCHMARK + role_id
end

function LoginDao:check_name_exist(name)
    local ok, code, udata = mongo_agent:find_one({ "player", { name = name }, { name = 1 } })
    if qfailed(code, ok) then
        log_err("[LoginDao][check_name_exist] name: %s find failed! code: %s, res: %s", name, code, udata)
        return false
    end
    return (udata ~= nil)
end

function LoginDao:new_player(open_id, player_id, data)
    local pdata = {
        nick = data.name,
        open_id = open_id,
        gender = data.gender,
        facade = data.custom,
        player_id = player_id,
        user_id = data.user_id,
        create_time = quanta.now
    }
    local ok, code, udata = mongo_agent:insert({ "player", pdata })
    if qfailed(code, ok) then
        log_err("[LoginDao][create_player] player_id: %s create failed! code: %s, res: %s", player_id, code, udata)
        return false
    end
    return true, SUCCESS
end

function LoginDao:check_player(params, ip, user_id, name)
    --检查名称合法性
    local converger = qconverger("check_name")
    converger:push(function()
        local lang, dev_plat = params.lang, params.dev_plat
        local check_res = event_mgr:notify_listener("on_safe_text", ip, lang, name, dev_plat)
        local check_ok, code, result_name = tunpack(check_res)
        if qfailed(code, check_ok) then
            log_err("[LoginServlet][on_role_create_req] ok:%s code:%s result_name:%s", check_ok, code, result_name)
        end
        return check_ok, code
    end)
    converger:push(function()
        if self:check_name_exist(name) then
            return false
        end
        return true, SUCCESS
    end)
    converger:push(function()
        return self:get_autoinc_id(user_id)
    end)
    return converger:execute()
end

function LoginDao:create_player(account, role_id, body)
    local converger = qconverger("create_player")
    converger:push(function()
        return self:new_player(self.open_id, role_id, body)
    end)
    converger:push(function()
        account:set_roles_field(role_id, body, true)
        return true, SUCCESS
    end)
    return converger:execute()
end

quanta.login_dao = LoginDao()

return LoginDao
