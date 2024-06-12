--login.lua
import("agent/mongo_agent.lua")
local log_err       = logger.err
local tunpack       = table.unpack
local qfailed       = quanta.failed
local makechan      = quanta.make_channel
local sformat       = string.format

local event_mgr     = quanta.get("event_mgr")
local mongo_agent   = quanta.get("mongo_agent")
local redis_agent   = quanta.get("redis_agent")

--[[
local protobuf_mgr  = quanta.get("protobuf_mgr")
local NAME_EXIST    = protobuf_mgr:error_code("LOGIN_ROLE_NAME_EXIST")
]]

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local Account       = import("login/account.lua")
local AC_LIMIT_KEY  = "account_limmit"

local LoginDao = singleton()

function LoginDao:__init()
end

function LoginDao:get_autoinc_id(user_id)
    local aok, acode, role_id = redis_agent:autoinc_id()
    if qfailed(acode, aok) then
        log_err("[LoginDao][get_autoinc_id] user_id: {} get_autoinc_id failed! code: {}, res: {}", user_id, acode, role_id)
        return false
    end
    return true, SUCCESS, role_id
end

function LoginDao:check_name_exist(name)
    local ok, code, udata = mongo_agent:find_one({ "player", { nick = name }, { nick = 1 } })
    if qfailed(code, ok) then
        log_err("[LoginDao][check_name_exist] name: {} find failed! code: {}, res: {}", name, code, udata)
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
        log_err("[LoginDao][create_player] player_id: {} create failed! code: {}, res: {}", player_id, code, udata)
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
            log_err("[LoginDao][check_player] user_id:{} ok:{} code:{} result_name:{}", user_id, check_ok, code, result_name)
        end
        return check_ok, code
    end)
    --临时屏蔽同名
    --[[
    channel:push(function()
        if self:check_name_exist(name) then
            return false, NAME_EXIST
        end
        return true, SUCCESS
    end)
    ]]
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

--账号数量
function LoginDao:account_count(channel)
    local ok, code, cur_num = mongo_agent:count({"account", { channel = channel}})
    if qfailed(code, ok) then
        log_err("[LoginDao][account_limit] load account num failed! code: {}, res: {}", code, cur_num)
        return false
    end
    return true, cur_num
end

--加载账号限制
function LoginDao:load_ac_limit(channel)
    local key = sformat("%s_%s", AC_LIMIT_KEY, channel)
    return redis_agent:load_msic(key)
end

quanta.login_dao = LoginDao()

return LoginDao
