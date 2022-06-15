--login_dao.lua
import("agent/mongo_agent.lua")

local log_err           = logger.err
local qfailed           = quanta.failed

local mongo_agent       = quanta.get("mongo_agent")

local LoginDao = singleton()

function LoginDao:__init()
end

function LoginDao:create_account(open_id, user_id, session_token)
    local udata = {
        roles = {},
        user_id = user_id,
        open_id = open_id,
        token = session_token
    }
    local ok, code, res = mongo_agent:insert({ "account", udata })
    if not ok or qfailed(code) then
        log_err("[LoginDao][create_account] insert failed! code: %s, res: %s", code, res)
        return
    end
    return udata
end

function LoginDao:load_account(open_id)
    local ok, code, udata = mongo_agent:find_one({ "account", { open_id = open_id } })
    if not ok or qfailed(code) then
        log_err("[LoginDao][load_account] find failed! code: %s, res: %s", code, udata)
        return false
    end
    return true, udata
end

function LoginDao:update_account_roles(user_id, new_roles)
    local udata = { ["$set"] = { roles = new_roles }}
    local ok, code, res = mongo_agent:update({ "account", udata, { user_id = user_id } })
    if not ok or qfailed(code) then
        log_err("[LoginDao][update_account] user_id(%s) update failed!: code: %s, res: %s!", user_id, code, res)
        return false
    end
    return true
end

function LoginDao:load_account_status(user_id)
    local ok, code, adata = mongo_agent:find_one({ "account_status", { user_id = user_id } })
    if not ok or qfailed(code) then
        log_err("[LoginDao][load_account_status] find failed! code: %s, res: %s", code, adata)
        return false
    end
    return true, adata
end

function LoginDao:update_account_status(user_id, udata)
    local ok, code, res = mongo_agent:update({ "account_status", udata, { user_id = user_id } })
    if not ok or qfailed(code) then
        log_err("[LoginDao][update_account_status] user_id(%s) update failed!: code: %s, res: %s!", user_id, code, res)
        return false
    end
    return true
end

quanta.login_dao = LoginDao()

return LoginDao
