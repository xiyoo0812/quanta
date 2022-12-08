--login_dao.lua
import("agent/mongo_agent.lua")

local log_err           = logger.err
local qfailed           = quanta.failed

local mongo_agent       = quanta.get("mongo_agent")

local MINUTE_5_S        = quanta.enum("PeriodTime", "MINUTE_5_S")

local LoginDao = singleton()
function LoginDao:__init()
end

function LoginDao:load_account(open_id)
    local ok, code, udata = mongo_agent:find_one({ "account", { open_id = open_id } })
    if qfailed(code, ok) then
        log_err("[LoginDao][load_account] open_id: %s find failed! code: %s, res: %s", open_id, code, udata)
        return false
    end
    return true, udata
end

function LoginDao:create_account(open_id, user_id, session_token)
    local udata = {
        roles = {},
        user_id = user_id,
        open_id = open_id,
        token = session_token,
        time = quanta.now,
    }
    local ok, code, res = mongo_agent:insert({ "account", udata })
    if qfailed(code, ok) then
        log_err("[LoginDao][create_account] open_id: %s insert failed! code: %s, res: %s", open_id, code, res)
        return
    end
    return udata
end

function LoginDao:create_player(user_id, open_id, role_info)
    local udata = {
        login_time = 0,
        online_time = 0,
        upgrade_time = 0,
        user_id = user_id,
        open_id = open_id,
        name = role_info.name,
        custom = role_info.custom,
        create_time = quanta.now,
        gender = role_info.gender,
        role_id = role_info.role_id
    }
    local ok, code, res = mongo_agent:insert({ "player", udata })
    if qfailed(code, ok) then
        log_err("[LoginDao][create_player] user_id: %s insert failed! code: %s, res: %s", user_id, code, res)
        return false
    end
    return true
end

function LoginDao:delete_player(role_id)
    local ok, code, res = mongo_agent:delete({ "player", { role_id = role_id } })
    if qfailed(code, ok) then
        log_err("[LoginDao][delete_player] role_id:%s delete failed! code: %s, res: %s", role_id, code, res)
        return false
    end
    return true
end

function LoginDao:update_account_roles(user_id, new_roles)
    local udata = { ["$set"] = { roles = new_roles }}
    local ok, code, res = mongo_agent:update({ "account", udata, { user_id = user_id } })
    if qfailed(code, ok) then
        log_err("[LoginDao][update_account] user_id(%s) update failed!: code: %s, res: %s!", user_id, code, res)
        return false
    end
    return true
end

function LoginDao:load_account_status(open_id)
    local ok, code, adata = mongo_agent:find_one({ "account_status", { open_id = open_id } })
    if qfailed(code, ok) then
        log_err("[LoginDao][load_account_status] open_id:%s find failed! code: %s, res: %s", open_id, code, adata)
        return false
    end
    return true, adata or {}
end

function LoginDao:update_account_status(session, info)
    local open_id = session.open_id
    local udata = {
        open_id = open_id,
        lobby = info.lobby,
        login_token = info.token,
        user_id = session.user_id,
        login_time = quanta.now + MINUTE_5_S
    }
    local ok, code, res = mongo_agent:update({ "account_status", udata, { open_id = open_id }, true })
    if qfailed(code, ok) then
        log_err("[LoginDao][update_account_status] user_id(%s) update failed!: code: %s, res: %s!", open_id, code, res)
        return false
    end
    return true
end

function LoginDao:check_name_exist(name)
    local ok, code, udata = mongo_agent:find_one({ "player", { name = name } })
    if qfailed(code, ok) then
        log_err("[LoginDao][check_name_exist] name: %s find failed! code: %s, res: %s", name, code, udata)
        return true
    end
    return udata
end

quanta.login_dao = LoginDao()

return LoginDao
