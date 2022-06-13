--login_servlet.lua
local lcrypt                = require("lcrypt")
local log_err               = logger.err
local log_info              = logger.info
local log_debug             = logger.debug
local qfailed               = quanta.failed
local guid_new              = lcrypt.guid_new
local trandom               = table_ext.random
local mrandom               = math_ext.rand
local tremove               = table.remove

local monitor               = quanta.get("monitor")
local login_mgr             = quanta.get("login_mgr")
local event_mgr             = quanta.get("event_mgr")
local thread_mgr            = quanta.get("thread_mgr")
local mongo_agent           = quanta.get("mongo_agent")
local client_mgr            = quanta.get("client_mgr")

local ErrorCode             = ncmd_cs.ErrorCode
local FRAME_FAILED          = ErrorCode.FRAME_FAILED
local FRAME_TOOFAST         = ErrorCode.FRAME_TOOFAST
local FRAME_SUCCESS         = ErrorCode.FRAME_SUCCESS
local SERVER_UPHOLD         = ErrorCode.LOGIN_SERVER_UPHOLD
local PLATFORM_ERROR        = ErrorCode.LOGIN_PLATFORM_ERROR
local ACCOUTN_INLINE        = ErrorCode.LOGIN_ACCOUTN_INLINE
local ACCOUTN_BANS          = ErrorCode.LOGIN_ACCOUTN_BANS
local VERIFY_FAILED         = ErrorCode.LOGIN_VERIFY_FAILED
local ROLE_NOT_EXIST        = ErrorCode.LOGIN_ROLE_NOT_EXIST
local ROLE_NUM_LIMIT        = ErrorCode.LOGIN_ROLE_NUM_LIMIT

local platform_type         = ncmd_cs.platform_type
local PLATFORM_GUEST        = platform_type.PLATFORM_GUEST
local PLATFORM_PASSWORD     = platform_type.PLATFORM_PASSWORD

local NCmdId                = ncmd_cs.NCmdId
local RANDOM_NAME_REQ       = NCmdId.NID_LOGIN_RANDOM_NAME_REQ
local ROLE_CREATE_REQ       = NCmdId.NID_LOGIN_ROLE_CREATE_REQ
local ROLE_CHOOSE_REQ       = NCmdId.NID_LOGIN_ROLE_CHOOSE_REQ
local ROLE_DELETE_REQ       = NCmdId.NID_LOGIN_ROLE_DELETE_REQ
local ACCOUNT_LOGIN_REQ     = NCmdId.NID_LOGIN_ACCOUNT_LOGIN_REQ
local ACCOUNT_RELOAD_REQ    = NCmdId.NID_LOGIN_ACCOUNT_RELOAD_REQ

local LoginServlet = singleton()
local prop = property(LoginServlet)
prop:reader("lobbys", {})
prop:reader("gateways", {})

function LoginServlet:__init()
    -- cs协议监听
    event_mgr:add_cmd_listener(self, RANDOM_NAME_REQ, "on_random_name_req")
    event_mgr:add_cmd_listener(self, ROLE_CREATE_REQ, "on_role_create_req")
    event_mgr:add_cmd_listener(self, ROLE_CHOOSE_REQ, "on_role_choose_req")
    event_mgr:add_cmd_listener(self, ROLE_DELETE_REQ, "on_role_delete_req")
    event_mgr:add_cmd_listener(self, ACCOUNT_LOGIN_REQ, "on_account_login_req")
    event_mgr:add_cmd_listener(self, ACCOUNT_RELOAD_REQ, "on_account_reload_req")
    --关注gateway和lobby
    monitor:watch_service_ready(self, "gateway")
    monitor:watch_service_close(self, "gateway")
    monitor:watch_service_ready(self, "lobby")
    monitor:watch_service_close(self, "lobby")
end

--账号登陆
function LoginServlet:on_account_login_req(session, body, session_id)
    local open_id, token, platform = body.open_id, body.session, body.platform
    log_info("[LoginServlet][on_account_login_req] open_id(%s) token(%s) login start!", open_id, token)
    if session.open_id then
        return client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, ACCOUTN_INLINE, session_id)
    end
    local _lock<close> = thread_mgr:lock(open_id)
    if not _lock then
        return client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, FRAME_TOOFAST, session_id)
    end
    if platform ~= PLATFORM_GUEST and platform ~= PLATFORM_PASSWORD then
        local ok = event_mgr:notify_listener("on_platform_login", open_id, token, platform)
        if not ok then
            login_mgr:send_errcode(session, ACCOUNT_LOGIN_REQ, PLATFORM_ERROR, session_id)
        end
        return
    end
    --检查账号信息
    local fok, fcode, udata = mongo_agent:find_one({ "account", {open_id = open_id}, {_id = 0} })
    if not fok or qfailed(fcode) then
        log_err("[LoginServlet][on_password_login] find failed! code: %s, res: %s", fcode, udata)
        return client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, FRAME_FAILED, session_id)
    end
    --创建账号
    if not udata then
        return self:create_account(session, open_id, token, session_id)
     end
     --密码验证
     if udata.token ~= token then
        log_err("[LoginServlet][on_password_login] verify failed! open_id: %s", open_id)
        return client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, VERIFY_FAILED, session_id)
    end
    --其他验证
    self:verify_account(session, udata, open_id, session_id)
end

--创建角色
function LoginServlet:on_role_create_req(session, body, session_id)
    local user_id, name, gender = body.user_id, body.name, body.gender
    log_info("[LoginServlet][on_role_create_req] user(%s) name(%s) create role start!", user_id, name)
    local role_count = #session.roles
    if role_count > 3 then
        log_err("[LoginServlet][on_role_create_req] user_id(%s) role num limit!", user_id)
        return client_mgr:callback_errcode(session, ROLE_CREATE_REQ, ROLE_NUM_LIMIT, session_id)
    end
    local role_id = guid_new(quanta.service, quanta.index)
    local add_role = { gender = gender, name = name, role_id = role_id }
    session.roles[role_count + 1] = add_role
    --更新数据库
    local udata = { open_id = session.open_id, user_id = user_id, roles = session.roles }
    local iok, icode, res = mongo_agent:update({ "account", udata, {user_id = user_id} })
    if not iok or qfailed(icode) then
        log_err("[LoginServlet][on_role_delete_req] user_id(%s) role_id(%s) update failed!: code: %s, res: %s!", user_id, role_id, icode, res)
        client_mgr:callback_errcode(session, ROLE_CREATE_REQ, FRAME_FAILED, session_id)
        self:delete_role(session, role_id)
        return
    end
    log_info("[LoginServlet][on_role_create_req] user_id(%s) create role %s success!", user_id, name)
    local callback_data = {error_code = 0, role = add_role }
    login_mgr:callback_by_id(session, ROLE_CREATE_REQ, callback_data, session_id)
end

--选择角色
function LoginServlet:on_role_choose_req(session, body, session_id)
    local user_id, role_id = body.user_id, body.role_id
    log_info("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) choose start!", user_id, role_id)
    if not self:find_role(session, role_id) then
        log_err("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) role nit exist!", user_id, role_id)
        return client_mgr:callback_errcode(session, ROLE_CHOOSE_REQ, ROLE_NOT_EXIST, session_id)
    end
    local fok, fcode, adata = mongo_agent:find_one({ "account_status", {role_id = role_id}, {_id = 0} })
    if not fok or qfailed(fcode) then
        log_err("[LoginServlet][on_role_choose_req] find failed! code: %s, res: %s", fcode, adata)
        return client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, FRAME_FAILED, session_id)
    end
    local ok, choose_data, acc_status = self.find_login_info(adata)
    if not ok then
        log_err("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) server uphold!", user_id, role_id)
        return client_mgr:callback_errcode(session, ROLE_CHOOSE_REQ, SERVER_UPHOLD, session_id)
    end
    local iok, icode, res = mongo_agent:update({ "account_status", acc_status, {user_id = user_id} })
    if not iok or qfailed(icode) then
        log_err("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) update failed!: code: %s, res: %s!", user_id, role_id, icode, res)
        client_mgr:callback_errcode(session, ROLE_CHOOSE_REQ, FRAME_FAILED, session_id)
        return
    end
    log_info("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) choose success!", user_id, role_id)
    login_mgr:callback_by_id(session, ROLE_CHOOSE_REQ, choose_data, session_id)
end

--删除角色
function LoginServlet:on_role_delete_req(session, body, session_id)
    local user_id, role_id = body.user_id, body.role_id
    log_info("[LoginServlet][on_role_delete_req] user_id(%s) role_id(%s) delete start!", user_id, role_id)
    local del_role = self:delete_role(session, role_id)
    if not del_role then
        log_err("[LoginServlet][on_role_delete_req] user_id(%s) role_id(%s) role nit exist!", user_id, role_id)
        return client_mgr:callback_errcode(session, ROLE_DELETE_REQ, ROLE_NOT_EXIST, session_id)
    end
    local udata = { open_id = session.open_id, user_id = user_id, roles = session.roles }
    local iok, icode, res = mongo_agent:update({ "account", udata, { user_id = user_id } })
    if not iok or qfailed(icode) then
        log_err("[LoginServlet][on_role_delete_req] user_id(%s) role_id(%s) update failed!: code: %s, res: %s!", user_id, role_id, icode, res)
        client_mgr:callback_errcode(session, ROLE_DELETE_REQ, FRAME_FAILED, session_id)
        session.roles[#session.roles] = del_role
        return
    end
    log_info("[LoginServlet][on_role_delete_req] user_id(%s) role_id(%s) delete success!", user_id, role_id)
    client_mgr:callback_errcode(session, ROLE_DELETE_REQ, FRAME_SUCCESS, session_id)
end

--账号重登
function LoginServlet:on_account_reload_req(session, body, session_id)
    local openid, token = body.openid, body.account_token
    log_info("[LoginServlet][on_account_reload_req] openid(%s) token(%s) reload start!", openid, token)
end

--随机名字
function LoginServlet:on_random_name_req(session, body, session_id)
end

--内部接口
-----------------------------------------------------
--验证账户
function LoginServlet:verify_account(session, udata, open_id, session_id)
    if udata.bantime and quanta.now < udata.bantime then
        log_err("[LoginServlet][verify_account] account is ban! open_id: %s", open_id)
        return client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, ACCOUTN_BANS, session_id)
    end
    self:save_account(session, udata)
    local callback_data = {error_code = 0, roles = udata.roles, user_id = udata.user_id }
    login_mgr:callback_by_id(session, ACCOUNT_LOGIN_REQ, callback_data, session_id)
    log_err("[LoginServlet][verify_account] success! open_id: %s", open_id)
end

--创建账号
function LoginServlet:create_account(session, open_id, token, session_id)
    local user_id = guid_new(quanta.service, quanta.index)
    local udata = { open_id = open_id, token = token, user_id = user_id, roles = {} }
    local iok, icode, res = mongo_agent:insert({ "account", udata })
    if not iok or qfailed(icode) then
        log_err("[LoginServlet][create_account] insert failed! code: %s, res: %s", icode, res)
        client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, FRAME_FAILED, session_id)
        return
    end
    self:save_account(session, udata)
    local callback_data = {error_code = 0, roles = {}, user_id = user_id }
    login_mgr:callback_by_id(session, ACCOUNT_LOGIN_REQ, callback_data, session_id)
    log_err("[LoginServlet][create_account] success! open_id: %s", open_id)
end

--保存账号
function LoginServlet:save_account(session, udata)
    session.roles = udata.roles
    session.open_id = udata.open_id
    session.user_id = udata.user_id
end

--查询角色
function LoginServlet:find_role(session, role_id)
    for i, role in pairs(session.roles or {}) do
        if role.role_id == role_id then
            return role
        end
    end
end

--删除角色
function LoginServlet:delete_role(session, role_id)
    local roles = session.roles
    for i, role in pairs(roles or {}) do
        if role.role_id == role_id then
            tremove(roles, i)
            return role
        end
    end
end

--网关和lobby相关接口
----------------------------------------------------------------
function LoginServlet:on_service_close(id, name, info)
    log_debug("[LoginServlet][on_service_close] name: %s", name)
    if name == "lobby" then
        self.lobbys[id] = nil
        return
    end
    local region = info.region
    local gate_region = self.gateways[region]
    for i, ginfo in pairs(gate_region or {}) do
        if ginfo.id == id then
            tremove(gate_region, i)
            break
        end
    end
end

function LoginServlet:on_service_ready(id, name, info)
    log_debug("[LoginServlet][on_service_ready] id: %s, info: %s", id, info)
    if name == "lobby" then
        self.lobbys[id] = info
        return
    end
    local region = info.region
    local gate_region = self.gateways[region]
    if not gate_region then
        self.gateways[region] = { info }
    end
    gate_region[#gate_region + 1] = info
end

function LoginServlet:find_login_info(user_id, adata)
    --分配lobby
    local lobby = adata.lobby or 0
    local status = adata.status or 0
    local lobby_info = self.lobbys[lobby]
    if status == 0 or not lobby_info then
        lobby_info = trandom(self.lobbys)
        if not lobby_info then
            return false
        end
        lobby = lobby_info.id
    end
    --分配gateway
    local region = lobby_info.region
    local gate_info = trandom(self.gateways[region])
    if not gate_info then
        return false
    end
    local token = mrandom(100000, 999999)
    local acc_status = {
        status = 1,
        token = token,
        lobby = lobby,
        user_id = user_id,
        time = quanta.now,
    }
    local gateway = {
        token = token,
        lobby = lobby,
        addr = gate_info.ip,
        port = gate_info.port,
        error_code = FRAME_SUCCESS
    }
    return true, gateway, acc_status
end

quanta.login_servlet = LoginServlet()

return LoginServlet
