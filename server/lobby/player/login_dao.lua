--login_dao.lua
import("agent/mongo_agent.lua")

local log_err       = logger.err
local mrandom       = qmath.random
local qfailed       = quanta.failed

local mongo_agent   = quanta.get("mongo_agent")

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

function LoginDao:fam_account_status(user_id)
    local new_token = mrandom()
    local data = { "account_status", {["$set"] = { login_token = new_token }}, { user_id = user_id }, false, { _id = 0 }, false }
    local ok, code, adata = mongo_agent:find_and_modify(data)
    if qfailed(code, ok) or (not adata) then
        log_err("[LoginDao][load_account_status] user_id: %s find failed! code: %s, res: %s", user_id, code, adata)
        return false
    end
    return true, adata.value, new_token
end

function LoginDao:clear_account_lobby_status(user_id)
    local udata = { ["$set"] = { lobby = 0 } }
    local ok, code, res = mongo_agent:update({ "account_status", udata, { user_id = user_id } })
    if qfailed(code, ok) then
        log_err("[LoginDao][clear_account_lobby_status] user_id(%s) update failed!: code: %s, res: %s!", user_id, code, res)
        return false
    end
    return true
end

quanta.login_dao = LoginDao()

return LoginDao
