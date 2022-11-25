--login_dao.lua
import("agent/mongo_agent.lua")

local log_err       = logger.err
local qfailed       = quanta.failed

local mongo_agent   = quanta.get("mongo_agent")

local MINUTE_5_S    = quanta.enum("PeriodTime", "MINUTE_5_S")

local LoginDao = singleton()

function LoginDao:__init()
end

function LoginDao:load_player(role_id)
    local ok, code, udata = mongo_agent:find_one({ "player", { role_id = role_id } })
    if qfailed(code, ok) then
        log_err("[LoginDao][load_player] role_id:%s find failed! code: %s, res: %s", role_id, code, udata)
        return false
    end
    return true, udata
end

function LoginDao:update_player(role_id, data)
    local udata = { ["$set"] = data }
    local ok, code, res = mongo_agent:update({ "player", udata, { role_id = role_id } })
    if qfailed(code, ok) then
        log_err("[LoginDao][update_player] role_id:%s find failed! code: %s, res: %s", role_id, code, res)
        return false
    end
    return true
end

function LoginDao:update_time(role_id, time_key, time)
    return self:update_player(role_id, { [time_key] = time })
end

function LoginDao:load_account_status(user_id)
    local ok, code, adata = mongo_agent:find_one({ "account_status", { user_id = user_id } })
    if qfailed(code, ok) then
        log_err("[LoginDao][load_account_status] user_id: %s find failed! code: %s, res: %s", user_id, code, adata)
        return false
    end
    return true, adata
end

function LoginDao:update_account_status(user_id, token)
    local udata = {
        ["$set"] = {
            lobby = 0,
            reload_token = token,
            reload_time = quanta.now + MINUTE_5_S
        }
    }
    local ok, code, res = mongo_agent:update({ "account_status", udata, { user_id = user_id } })
    if qfailed(code, ok) then
        log_err("[LoginDao][update_account_status] user_id(%s) update failed!: code: %s, res: %s!", user_id, code, res)
        return false
    end
    return true
end

quanta.login_dao = LoginDao()

return LoginDao
