--login.lua

local log_err       = logger.err
local tunpack       = table.unpack
local qfailed       = quanta.failed
local makechan      = quanta.make_channel
local sformat       = string.format

local event_mgr     = quanta.get("event_mgr")
local mongo_agent   = quanta.get("mongo_agent")
local redis_agent   = quanta.get("redis_agent")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local BENCHMARK     = environ.number("QUANTA_DB_BENCHMARK")
local AUTOINCKEY    = environ.get("QUANTA_DB_AUTOINCKEY", "COUNTER:QUANTA:ROLE")
local NAMESPACE     = environ.get("QUANTA_NAMESPACE")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local NAME_EXIST    = protobuf_mgr:error_code("LOGIN_ROLE_NAME_EXIST")
local DAY_S         = quanta.enum("PeriodTime", "DAY_S")

local Account       = import("login/account.lua")

local LoginDao = singleton()

function LoginDao:__init()
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
    local ok, code, udata = mongo_agent:find_one({ "player", { nick = name }, { nick = 1 } })
    if qfailed(code, ok) then
        log_err("[LoginDao][check_name_exist] name: %s find failed! code: %s, res: %s", name, code, udata)
        return false
    end
    return (udata ~= nil)
end

function LoginDao:create_player(open_id, player_id, data)
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
    return true
end

function LoginDao:check_player(user_id, name)
    --检查名称合法性
    local channel = makechan("check_name")
    channel:push(function()
        local check_res = event_mgr:notify_listener("on_safe_text", user_id, name)
        local check_ok, code, result_name = tunpack(check_res)
        if qfailed(code, check_ok) then
            log_err("[LoginDao][check_player] user_id:%s ok:%s code:%s result_name:%s", user_id, check_ok, code, result_name)
        end
        return check_ok, code
    end)
    channel:push(function()
        if self:check_name_exist(name) then
            return false, NAME_EXIST
        end
        return true, SUCCESS
    end)
    channel:push(function()
        return self:get_autoinc_id(user_id)
    end)
    return channel:execute()
end

function LoginDao:load_account(open_id)
    local account = Account(open_id)
    if not account:load() then
        return
    end
    return account
end

--保存数据服token
function LoginDao:save_data_token(role_id, token)
    local key = sformat("LOGIN:%s:data_token:%s", NAMESPACE, role_id)
    --有效期24小时
    local aok, acode, res = redis_agent:execute({ "SETEX", key, DAY_S, token }, role_id)
    if qfailed(acode, aok) then
        log_err("[LoginDao][save_data_token] player_id: %s save_data_token failed! code: %s, res: %s", role_id, acode, res)
        return false
    end
    return true
end

quanta.login_dao = LoginDao()

return LoginDao
