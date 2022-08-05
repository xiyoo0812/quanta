--login_servlet.lua
local lcrypt                = require("lcrypt")
local log_err               = logger.err
local log_info              = logger.info
local log_debug             = logger.debug
local qfailed               = quanta.failed
local guid_new              = lcrypt.guid_new
local trandom               = table_ext.random
local mrandom               = math_ext.random
local tremove               = table.remove

local monitor               = quanta.get("monitor")
local login_dao             = quanta.get("login_dao")
local login_mgr             = quanta.get("login_mgr")
local event_mgr             = quanta.get("event_mgr")
local thread_mgr            = quanta.get("thread_mgr")
local client_mgr            = quanta.get("client_mgr")
local protobuf_mgr          = quanta.get("protobuf_mgr")

local FRAME_FAILED          = protobuf_mgr:error_code("FRAME_FAILED")
local FRAME_TOOFAST         = protobuf_mgr:error_code("FRAME_TOOFAST")
local FRAME_SUCCESS         = protobuf_mgr:error_code("FRAME_SUCCESS")
local SERVER_UPHOLD         = protobuf_mgr:error_code("LOGIN_SERVER_UPHOLD")
local ACCOUTN_INLINE        = protobuf_mgr:error_code("LOGIN_ACCOUTN_INLINE")
local ACCOUTN_BANS          = protobuf_mgr:error_code("LOGIN_ACCOUTN_BANS")
local VERIFY_FAILED         = protobuf_mgr:error_code("LOGIN_VERIFY_FAILED")
local ROLE_NOT_EXIST        = protobuf_mgr:error_code("LOGIN_ROLE_NOT_EXIST")
local ROLE_NUM_LIMIT        = protobuf_mgr:error_code("LOGIN_ROLE_NUM_LIMIT")
local ROLE_NAME_EXIST       = protobuf_mgr:error_code("LOGIN_ROLE_NAME_EXIST")
local ACCOUTN_OFFLINE       = protobuf_mgr:error_code("LOGIN_ACCOUTN_OFFLINE")

local RANDOM_NAME_REQ       = protobuf_mgr:msg_id("NID_LOGIN_RANDOM_NAME_REQ")
local ROLE_CREATE_REQ       = protobuf_mgr:msg_id("NID_LOGIN_ROLE_CREATE_REQ")
local ROLE_CHOOSE_REQ       = protobuf_mgr:msg_id("NID_LOGIN_ROLE_CHOOSE_REQ")
local ROLE_DELETE_REQ       = protobuf_mgr:msg_id("NID_LOGIN_ROLE_DELETE_REQ")
local ACCOUNT_LOGIN_REQ     = protobuf_mgr:msg_id("NID_LOGIN_ACCOUNT_LOGIN_REQ")
local ACCOUNT_RELOAD_REQ    = protobuf_mgr:msg_id("NID_LOGIN_ACCOUNT_RELOAD_REQ")

local PLATFORM_PASSWORD     = protobuf_mgr:enum("platform_type", "PLATFORM_PASSWORD")

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
    local open_id, token, platform = body.openid, body.session, body.platform
    log_debug("[LoginServlet][on_account_login_req] open_id(%s) token(%s) login start!", open_id, token)
    if session.open_id then
        return client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, ACCOUTN_INLINE, session_id)
    end
    local _lock<close> = thread_mgr:lock(open_id)
    if not _lock then
        return client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, FRAME_TOOFAST, session_id)
    end
    if platform > PLATFORM_PASSWORD then
        local ok, code = event_mgr:notify_listener("on_platform_login", open_id, token, platform)
        if not ok or qfailed(code) then
            login_mgr:send_errcode(session, ACCOUNT_LOGIN_REQ, ok and code or FRAME_FAILED, session_id)
        end
    end
    --加载账号信息
    local ok, udata = login_dao:load_account(open_id)
    if not ok then
        return client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, FRAME_FAILED, session_id)
    end
    --创建账号
    if not udata then
        return self:create_account(session, open_id, token, session_id)
     end
     --密码验证
     if platform == PLATFORM_PASSWORD and udata.token ~= token then
        log_err("[LoginServlet][on_password_login] verify failed! open_id: %s", open_id)
        return client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, VERIFY_FAILED, session_id)
    end
    --其他验证
    self:verify_account(session, udata, open_id, session_id, ACCOUNT_LOGIN_REQ)
end

--创建角色
function LoginServlet:on_role_create_req(session, body, session_id)
    local user_id, name, gender, model = body.user_id, body.name, body.gender, body.model
    log_debug("[LoginServlet][on_role_create_req] user(%s) name(%s) create role start!", user_id, name)
    if not session.open_id then
        log_err("[LoginServlet][on_role_create_req] user_id(%s) need login!", user_id)
        return client_mgr:callback_errcode(session, ROLE_CREATE_REQ, ACCOUTN_OFFLINE, session_id)
    end
    local role_count = #session.roles
    if role_count >= 3 then
        log_err("[LoginServlet][on_role_create_req] user_id(%s) role num limit!", user_id)
        return client_mgr:callback_errcode(session, ROLE_CREATE_REQ, ROLE_NUM_LIMIT, session_id)
    end
    if login_dao:check_name_exist(name) then
        log_err("[LoginServlet][on_role_create_req] user_id(%s) name %s exist!", user_id, name)
        return client_mgr:callback_errcode(session, ROLE_CREATE_REQ, ROLE_NAME_EXIST, session_id)
    end
    --创建角色
    local role_id = guid_new(quanta.service, quanta.index)
    local add_role = { gender = gender, name = name, role_id = role_id, model = model }
    if not login_dao:create_player(user_id, add_role) then
        return client_mgr:callback_errcode(session, ROLE_CREATE_REQ, FRAME_FAILED, session_id)
    end
    --更新数据库
    session.roles[role_count + 1] = add_role
    if not login_dao:update_account_roles(user_id, session.roles) then
        --失败删除角色
        login_dao:delete_player(role_id)
        self:delete_role(session, role_id)
        return client_mgr:callback_errcode(session, ROLE_CREATE_REQ, FRAME_FAILED, session_id)
    end
    log_info("[LoginServlet][on_role_create_req] user_id(%s) create role %s success!", user_id, name)
    local callback_data = {error_code = 0, role = add_role }
    client_mgr:callback_by_id(session, ROLE_CREATE_REQ, callback_data, session_id)
end

--选择角色
function LoginServlet:on_role_choose_req(session, body, session_id)
    local user_id, role_id, open_id = body.user_id, body.role_id, session.open_id
    log_debug("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) choose start!", user_id, role_id)
    if not open_id then
        log_err("[LoginServlet][on_role_choose_req] user_id(%s) need login!", user_id)
        return client_mgr:callback_errcode(session, ROLE_CREATE_REQ, ACCOUTN_OFFLINE, session_id)
    end
    if not self:find_role(session, role_id) then
        log_err("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) role nit exist!", user_id, role_id)
        return client_mgr:callback_errcode(session, ROLE_CHOOSE_REQ, ROLE_NOT_EXIST, session_id)
    end
    local ok, adata = login_dao:load_account_status(open_id)
    if not ok then
        return client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, FRAME_FAILED, session_id)
    end
    local fok, gateway = self:find_gateway(user_id, adata)
    log_debug("[LoginServlet][on_role_choose_req] choose gateway(%s)!", gateway)
    if not fok then
        log_err("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) server uphold!", user_id, role_id)
        return client_mgr:callback_errcode(session, ROLE_CHOOSE_REQ, SERVER_UPHOLD, session_id)
    end
    if not login_dao:update_account_status(session, gateway) then
        return client_mgr:callback_errcode(session, ROLE_CHOOSE_REQ, FRAME_FAILED, session_id)
    end
    log_info("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) choose success!", user_id, role_id)
    client_mgr:callback_by_id(session, ROLE_CHOOSE_REQ, gateway, session_id)
end

--删除角色
function LoginServlet:on_role_delete_req(session, body, session_id)
    local user_id, role_id = body.user_id, body.role_id
    log_debug("[LoginServlet][on_role_delete_req] user_id(%s) role_id(%s) delete start!", user_id, role_id)
    if not session.open_id then
        log_err("[LoginServlet][on_role_delete_req] user_id(%s) need login!", user_id)
        return client_mgr:callback_errcode(session, ROLE_CREATE_REQ, ACCOUTN_OFFLINE, session_id)
    end
    local del_role = self:delete_role(session, role_id)
    if not del_role then
        log_err("[LoginServlet][on_role_delete_req] user_id(%s) role_id(%s) role nit exist!", user_id, role_id)
        return client_mgr:callback_errcode(session, ROLE_DELETE_REQ, ROLE_NOT_EXIST, session_id)
    end
    if not login_dao:update_account_roles(user_id, session.roles) then
        session.roles[#session.roles + 1] = del_role
        return client_mgr:callback_errcode(session, ROLE_DELETE_REQ, FRAME_FAILED, session_id)
    end
    if not login_dao:delete_player(role_id)  then
        return client_mgr:callback_errcode(session, ROLE_DELETE_REQ, FRAME_FAILED, session_id)
    end
    log_info("[LoginServlet][on_role_delete_req] user_id(%s) role_id(%s) delete success!", user_id, role_id)
    client_mgr:callback_errcode(session, ROLE_DELETE_REQ, FRAME_SUCCESS, session_id)
end

--账号重登
function LoginServlet:on_account_reload_req(session, body, session_id)
    local open_id, token = body.openid, body.account_token
    log_debug("[LoginServlet][on_account_reload_req] openid(%s) token(%s) reload start!", open_id, token)
    if session.open_id then
        return client_mgr:callback_errcode(session, ACCOUNT_RELOAD_REQ, ACCOUTN_INLINE, session_id)
    end
    local _lock<close> = thread_mgr:lock(open_id)
    if not _lock then
        return client_mgr:callback_errcode(session, ACCOUNT_RELOAD_REQ, FRAME_TOOFAST, session_id)
    end
    --验证token
    local ok, adata = login_dao:load_account_status(open_id)
    if not ok then
        return client_mgr:callback_errcode(session, ACCOUNT_RELOAD_REQ, FRAME_FAILED, session_id)
    end
    if not adata.reload_time or token ~= adata.reload_token or quanta.now > adata.reload_time then
        log_err("[LoginServlet][on_account_reload_req] verify failed! open_id: %s, time: %s, adata: %s", open_id, quanta.now, adata)
        return client_mgr:callback_errcode(session, ACCOUNT_RELOAD_REQ, VERIFY_FAILED, session_id)
    end
    --加载账号信息
    local lok, udata = login_dao:load_account(open_id)
    if not lok then
        return client_mgr:callback_errcode(session, ACCOUNT_RELOAD_REQ, FRAME_FAILED, session_id)
    end
    --其他验证
    self:verify_account(session, udata, open_id, session_id, ACCOUNT_RELOAD_REQ)
end

--随机名字
function LoginServlet:on_random_name_req(session, body, session_id)
    local rname = login_dao:random_name()
    log_debug("[LoginServlet][on_random_name_req] open_id(%s) randname: %s!",session.open_id, rname)
    local callback_data = { error_code = 0, name = rname }
    client_mgr:callback_by_id(session, RANDOM_NAME_REQ, callback_data, session_id)
end

--内部接口
-----------------------------------------------------
--验证账户
function LoginServlet:verify_account(session, udata, open_id, session_id, cmd_id)
    if udata.bantime and quanta.now < udata.bantime then
        log_err("[LoginServlet][verify_account] account is ban! open_id: %s", open_id)
        return client_mgr:callback_errcode(session, cmd_id, ACCOUTN_BANS, session_id)
    end
    self:save_account(session, udata)
    local callback_data = { error_code = 0, roles = udata.roles, user_id = udata.user_id }
    client_mgr:callback_by_id(session, cmd_id, callback_data, session_id)
    log_info("[LoginServlet][verify_account] success! open_id: %s", open_id)
end

--创建账号
function LoginServlet:create_account(session, open_id, token, session_id)
    local user_id = guid_new(quanta.service, quanta.index)
    local udata = login_dao:create_account(open_id, user_id, token)
    if not udata then
        client_mgr:callback_errcode(session, ACCOUNT_LOGIN_REQ, FRAME_FAILED, session_id)
        return
    end
    self:save_account(session, udata)
    local callback_data = { error_code = 0, roles = {}, user_id = user_id }
    client_mgr:callback_by_id(session, ACCOUNT_LOGIN_REQ, callback_data, session_id)
    log_info("[LoginServlet][create_account] success! open_id: %s", open_id)
end

--保存账号
function LoginServlet:save_account(session, udata)
    log_debug("[LoginServlet][save_account] success! udata: %s", udata)
    session.roles = udata.roles or {}
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
    log_debug("[LoginServlet][on_service_close] node: %s-%s", name, id)
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
    log_debug("[LoginServlet][on_service_ready] node: %s-%s, info: %s", name, id, info)
    if name == "lobby" then
        self.lobbys[id] = info
        return
    end
    local region = info.region
    local gate_region = self.gateways[region]
    if not gate_region then
        self.gateways[region] = { info }
        return
    end
    gate_region[#gate_region + 1] = info
end

function LoginServlet:find_gateway(user_id, adata)
    --分配lobby
    local lobby = adata.lobby or 0
    local lobby_info = self.lobbys[lobby]
    if not lobby_info then
        lobby, lobby_info = trandom(self.lobbys)
        if not lobby then
            return false
        end
    end
    --分配gateway
    local region = lobby_info.region
    local _, gate_info = trandom(self.gateways[region])
    if not gate_info then
        return false
    end
    local gateway = {
        lobby = lobby,
        token = mrandom(),
        addr = gate_info.ip,
        port = gate_info.port,
        error_code = FRAME_SUCCESS
    }
    return true, gateway
end

quanta.login_servlet = LoginServlet()

return LoginServlet
