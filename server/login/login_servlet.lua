--login_servlet.lua
local lcodec                = require("lcodec")
local luabus                = require("luabus")

local log_err               = logger.err
local log_info              = logger.info
local log_debug             = logger.debug
local qfailed               = quanta.failed
local trandom               = qtable.random
local mrandom               = qmath.random
local tremove               = table.remove
local tunpack               = table.unpack
local lbusdns               = luabus.dns
local guid_encode           = lcodec.guid_encode

local monitor               = quanta.get("monitor")
local login_dao             = quanta.get("login_dao")
local event_mgr             = quanta.get("event_mgr")
local thread_mgr            = quanta.get("thread_mgr")
local update_mgr            = quanta.get("update_mgr")
local client_mgr            = quanta.get("client_mgr")
local protobuf_mgr          = quanta.get("protobuf_mgr")

local FRAME_FAILED          = protobuf_mgr:error_code("FRAME_FAILED")
local FRAME_TOOFAST         = protobuf_mgr:error_code("FRAME_TOOFAST")
local FRAME_SUCCESS         = protobuf_mgr:error_code("FRAME_SUCCESS")
local SERVER_UPHOLD         = protobuf_mgr:error_code("LOGIN_SERVER_UPHOLD")
local ACCOUTN_INLINE        = protobuf_mgr:error_code("LOGIN_ACCOUTN_INLINE")
local VERIFY_FAILED         = protobuf_mgr:error_code("LOGIN_VERIFY_FAILED")
local ROLE_NOT_EXIST        = protobuf_mgr:error_code("LOGIN_ROLE_NOT_EXIST")
local ROLE_NUM_LIMIT        = protobuf_mgr:error_code("LOGIN_ROLE_NUM_LIMIT")
local ACCOUTN_OFFLINE       = protobuf_mgr:error_code("LOGIN_ACCOUTN_OFFLINE")

local MINUTE_5_S            = quanta.enum("PeriodTime", "MINUTE_5_S")
local PLATFORM_PASSWORD     = protobuf_mgr:enum("platform_type", "PLATFORM_PASSWORD")

local LoginServlet = singleton()
local prop = property(LoginServlet)
prop:reader("lobbys", {})
prop:reader("gateways", {})
prop:reader("gateaddrs", {})

function LoginServlet:__init()
    -- cs协议监听
    protobuf_mgr:register(self, "NID_LOGIN_RANDOM_NAME_REQ", "on_random_name_req")
    protobuf_mgr:register(self, "NID_LOGIN_ROLE_CREATE_REQ", "on_role_create_req")
    protobuf_mgr:register(self, "NID_LOGIN_ROLE_CHOOSE_REQ", "on_role_choose_req")
    protobuf_mgr:register(self, "NID_LOGIN_ROLE_DELETE_REQ", "on_role_delete_req")
    protobuf_mgr:register(self, "NID_LOGIN_ACCOUNT_LOGIN_REQ", "on_account_login_req")
    protobuf_mgr:register(self, "NID_LOGIN_ACCOUNT_RELOAD_REQ", "on_account_reload_req")
    --关注gateway和lobby
    monitor:watch_service_ready(self, "gateway")
    monitor:watch_service_close(self, "gateway")
    monitor:watch_service_ready(self, "lobby")
    monitor:watch_service_close(self, "lobby")
    --定时器
    update_mgr:attach_minute(self)
end

--账号登陆
function LoginServlet:on_account_login_req(session, cmd_id, body, session_id)
    local open_id, access_token, platform = body.openid, body.session, body.platform
    log_debug("[LoginServlet][on_account_login_req] open_id(%s) token(%s) body:%s login req!", open_id, access_token, body)
    if session.account then
        return client_mgr:callback_errcode(session, cmd_id, ACCOUTN_INLINE, session_id)
    end
    local _lock<close> = thread_mgr:lock(open_id)
    if not _lock then
        return client_mgr:callback_errcode(session, cmd_id, FRAME_TOOFAST, session_id)
    end
    local device_id = body.device_id
    local account_params = {}
    if platform >= PLATFORM_PASSWORD then
        --登录验证
        local result = event_mgr:notify_listener("on_platform_login", platform, open_id, access_token, body, account_params)
        local ok, code, sdk_open_id, sdk_device_id = tunpack(result)
        local login_failed, login_code = qfailed(code, ok)
        if login_failed then
            log_err("[LoginServlet][on_account_login_req] verify failed! open_id: %s token:%s code:%s", open_id, access_token, login_code)
            client_mgr:callback_errcode(session, cmd_id, login_code, session_id)
            return false
        end
        -- 三方信息
        open_id, device_id = sdk_open_id, sdk_device_id
    end
    --加载账号信息
    local account = login_dao:load_account(open_id)
    if not account then
        log_err("[LoginServlet][on_account_login_req] load account failed! open_id: %s token:%s", open_id, access_token)
        return client_mgr:callback_errcode(session, cmd_id, FRAME_FAILED, session_id)
    end
    --创建账号
    if account:is_newbee() then
        if not account:create(access_token, device_id, account_params) then
            log_err("[LoginServlet][on_account_login_req] open_id(%s) create account failed!", open_id)
            return client_mgr:callback_errcode(session, cmd_id, FRAME_FAILED, session_id)
        end
        session.account = account
        event_mgr:notify_listener("on_account_create", account, device_id)
        client_mgr:callback_by_id(session, cmd_id, account:pack2client(), session_id)
        log_info("[LoginServlet][on_account_login_req] newbee success! open_id: %s", open_id)
        return
    end
    --密码验证
    if platform == PLATFORM_PASSWORD and account:get_token() ~= access_token then
        log_err("[LoginServlet][on_password_login] verify failed! open_id: %s token: %s-%s", open_id, access_token, account:get_token())
        return client_mgr:callback_errcode(session, cmd_id, VERIFY_FAILED, session_id)
    end
    session.account = account
    account:save_token(access_token)
    account:save_device_id(device_id)
    account:update_params(account_params)
    event_mgr:notify_listener("on_account_login", account:get_user_id(), open_id, device_id)
    if not client_mgr:callback_by_id(session, cmd_id, account:pack2client(), session_id) then
        log_info("[LoginServlet][on_account_login_req] callback failed! open_id: %s, user_id：%s", open_id, account:get_user_id())
        return
    end
    log_info("[LoginServlet][on_account_login_req] success! open_id: %s, user_id：%s", open_id, account:get_user_id())
end

--创建角色
function LoginServlet:on_role_create_req(session, cmd_id, body, session_id)
    local user_id, name = body.user_id, body.name
    log_debug("[LoginServlet][on_role_create_req] user(%s) name(%s) create role req!", user_id, name)
    local account = session.account
    if not account or account.user_id ~= user_id then
        log_err("[LoginServlet][on_role_create_req] user_id(%s) need login!", user_id)
        return client_mgr:callback_errcode(session, cmd_id, ACCOUTN_OFFLINE, session_id)
    end
    if account:get_role_count() > 1 then
        log_err("[LoginServlet][on_role_create_req] user_id(%s) role num limit!", user_id)
        return client_mgr:callback_errcode(session, cmd_id, ROLE_NUM_LIMIT, session_id)
    end
    --检查名称合法性
    local ok, codatas = login_dao:check_player(account.params, session.ip, user_id, name)
    if not ok then
        return client_mgr:callback_errcode(session, cmd_id, codatas, session_id)
    end
    --创建角色
    local role_id = codatas[3]
    if not login_dao:create_player(account:get_open_id(), role_id, body) then
        log_err("[LoginServlet][on_role_create_req] user_id(%s) create role failed!", user_id)
        return client_mgr:callback_errcode(session, cmd_id, FRAME_FAILED, session_id)
    end
    account:save_roles_field(role_id, body)
    event_mgr:notify_listener("on_role_create", user_id, role_id, body)
    local rdata = { role_id = role_id, gender = body.gender, name = body.name }
    if not client_mgr:callback_by_id(session, cmd_id, { error_code = 0, role = rdata }, session_id) then
        log_info("[LoginServlet][on_role_create_req] user_id(%s) create role %s callback failed!", user_id, name)
        return
    end
    log_info("[LoginServlet][on_role_create_req] user_id(%s) create role %s success!", user_id, name)
end

--选择角色
function LoginServlet:on_role_choose_req(session, cmd_id, body, session_id)
    local user_id, role_id = body.user_id, body.role_id
    log_debug("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) choose req!", user_id, role_id)
    local account = session.account
    if not account then
        log_err("[LoginServlet][on_role_choose_req] user_id(%s) need login!", user_id)
        return client_mgr:callback_errcode(session, cmd_id, ACCOUTN_OFFLINE, session_id)
    end
    local role = account:get_role(role_id)
    if not role then
        log_err("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) role nit exist!", user_id, role_id)
        return client_mgr:callback_errcode(session, cmd_id, ROLE_NOT_EXIST, session_id)
    end
    local fok, gateway = self:find_gateway(account)
    log_debug("[LoginServlet][on_role_choose_req] choose gateway(%s)!", gateway)
    if not fok then
        log_err("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) server uphold!", user_id, role_id)
        return client_mgr:callback_errcode(session, cmd_id, SERVER_UPHOLD, session_id)
    end
    account:save_lobby(gateway.lobby)
    account:set_login_token(role_id, gateway.token, MINUTE_5_S)
    --保存数据服token到redis
    login_dao:save_data_token(role_id, gateway.token)
    if not client_mgr:callback_by_id(session, cmd_id, gateway, session_id) then
        log_info("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) callback failed!", user_id, role_id)
        return
    end
    log_info("[LoginServlet][on_role_choose_req] user_id(%s) role_id(%s) choose success!", user_id, role_id)
end

--删除角色
function LoginServlet:on_role_delete_req(session, cmd_id, body, session_id)
    local user_id, role_id = body.user_id, body.role_id
    log_debug("[LoginServlet][on_role_delete_req] user_id(%s) role_id(%s) delete req!", user_id, role_id)
    local account = session.account
    if not account or account:get_user_id() ~= user_id then
        log_err("[LoginServlet][on_role_delete_req] user_id(%s) need login!", user_id)
        return client_mgr:callback_errcode(session, cmd_id, ACCOUTN_OFFLINE, session_id)
    end
    if not account:del_role(role_id) then
        log_err("[LoginServlet][on_role_delete_req] user_id(%s) role_id(%s) role nit exist!", user_id, role_id)
        return client_mgr:callback_errcode(session, cmd_id, ROLE_NOT_EXIST, session_id)
    end
    if not client_mgr:callback_errcode(session, cmd_id, FRAME_SUCCESS, session_id) then
        log_info("[LoginServlet][on_role_delete_req] user_id(%s) role_id(%s) callback failed!", user_id, role_id)
        return
    end
    log_info("[LoginServlet][on_role_delete_req] user_id(%s) role_id(%s) delete success!", user_id, role_id)
end

--账号重登
function LoginServlet:on_account_reload_req(session, cmd_id, body, session_id)
    local open_id, token, device_id = body.openid, body.session, body.device_id
    log_debug("[LoginServlet][on_account_reload_req] openid(%s) token(%s) reload req!", open_id, token)
    if session.account then
        return client_mgr:callback_errcode(session, cmd_id, ACCOUTN_INLINE, session_id)
    end
    local _lock<close> = thread_mgr:lock(open_id)
    if not _lock then
        return client_mgr:callback_errcode(session, cmd_id, FRAME_TOOFAST, session_id)
    end
    --验证token
    local account = login_dao:load_account(open_id)
    if not account then
        log_err("[LoginServlet][on_account_login_req] load account failed! open_id: %s token:%s", open_id, token)
        return client_mgr:callback_errcode(session, cmd_id, FRAME_FAILED, session_id)
    end
    if account:is_newbee() then
        log_err("[LoginServlet][on_account_reload_req] open_id(%s) load account status failed!", open_id)
        return client_mgr:callback_errcode(session, cmd_id, FRAME_FAILED, session_id)
    end
    local old_token = account:get_token()
    if token ~= old_token or device_id ~= account:get_device_id() then
        log_err("[LoginServlet][on_account_reload_req] verify failed! open_id: %s, token: %s-%s", open_id, token, old_token)
        return client_mgr:callback_errcode(session, cmd_id, VERIFY_FAILED, session_id)
    end
    session.account = account
    if not client_mgr:callback_by_id(session, cmd_id, account:pack2client(), session_id) then
        log_info("[LoginServlet][on_account_reload_req] callback failed! open_id: %s", open_id)
        return
    end
    log_info("[LoginServlet][on_account_reload_req] success! open_id: %s, user_id: %s", open_id, account:get_user_id())
end

--随机名字
function LoginServlet:on_random_name_req(session, cmd_id, body, session_id)
    local rname = guid_encode()
    log_debug("[LoginServlet][on_random_name_req] open_id(%s) randname: %s!", session.open_id, rname)
    local callback_data = { error_code = 0, name = rname }
    if not client_mgr:callback_by_id(session, cmd_id, callback_data, session_id) then
        log_info("[LoginServlet][on_random_name_req] callback failed! open_id: %s", session.open_id)
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

function LoginServlet:find_gateway(account)
    --分配lobby
    local lobby = account:get_lobby()
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
    local ip, port = gate_info.ip, gate_info.port
    local gateway = {
        port = port,
        lobby = lobby,
        token = mrandom(),
        addrs = self:parse_addr(ip),
        error_code = FRAME_SUCCESS
    }
    return true, gateway
end

function LoginServlet:parse_addr(domain)
    local addrs = self.gateaddrs[domain]
    if not addrs then
        addrs = lbusdns(domain)
        if addrs then
            self.gateaddrs[domain] = addrs
        end
    end
    return addrs
end

function LoginServlet:on_minute()
    for domain in pairs(self.gateaddrs) do
        self.gateaddrs[domain] = lbusdns(domain)
    end
end

quanta.login_servlet = LoginServlet()

return LoginServlet
