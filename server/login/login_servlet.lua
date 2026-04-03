--login_servlet.lua

local log_err               = logger.err
local log_info              = logger.info
local log_debug             = logger.debug
local qfailed               = quanta.failed
local tunpack               = table.unpack
local guid_encode           = codec.guid_encode

local login_dao             = quanta.get("login_dao")
local login_mgr             = quanta.get("login_mgr")
local event_mgr             = quanta.get("event_mgr")
local router_mgr            = quanta.get("router_mgr")
local protobuf_mgr          = quanta.get("protobuf_mgr")

local FRAME_FAILED          = protobuf_mgr:error_code("FRAME_FAILED")
local FRAME_SUCCESS         = protobuf_mgr:error_code("FRAME_SUCCESS")
local SERVER_UPHOLD         = protobuf_mgr:error_code("LOGIN_SERVER_UPHOLD")
local ACCOUNT_INLINE        = protobuf_mgr:error_code("LOGIN_ACCOUNT_INLINE")
local VERIFY_FAILED         = protobuf_mgr:error_code("LOGIN_VERIFY_FAILED")
local PLAYER_NOT_EXIST      = protobuf_mgr:error_code("LOGIN_PLAYER_NOT_EXIST")
local PLAYER_NUM_LIMIT      = protobuf_mgr:error_code("LOGIN_PLAYER_NUM_LIMIT")
local ACCOUNT_OFFLINE       = protobuf_mgr:error_code("LOGIN_ACCOUNT_OFFLINE")

local PLATFORM_PASSWORD     = protobuf_mgr:enum("platform_type", "PLATFORM_PASSWORD")

local LoginServlet = singleton()

function LoginServlet:__init()
    -- cs协议监听
    protobuf_mgr:register(self, "NID_LOGIN_RANDOM_NAME_REQ", "on_random_name_req")
    protobuf_mgr:register(self, "NID_LOGIN_PLAYER_CREATE_REQ", "on_player_create_req")
    protobuf_mgr:register(self, "NID_LOGIN_PLAYER_CHOOSE_REQ", "on_player_choose_req")
    protobuf_mgr:register(self, "NID_LOGIN_PLAYER_DELETE_REQ", "on_player_delete_req")
    protobuf_mgr:register(self, "NID_LOGIN_ACCOUNT_LOGIN_REQ", "on_account_login_req")
    protobuf_mgr:register(self, "NID_LOGIN_ACCOUNT_RELOAD_REQ", "on_account_reload_req")
    --添加事件监听
    event_mgr:add_listener(self, "on_safe_text")
end

--屏蔽词库校验
function LoginServlet:on_safe_text(user_id, text)
    return FRAME_SUCCESS, text
end

--账号登陆
function LoginServlet:on_account_login_req(session, message, body, response)
    local open_id, access_token, platform, channel = body.openid, body.session, body.platform, body.package_channel
    log_debug("[LoginServlet][on_account_login_req] open_id({}) token({}) body:{} login req!", open_id, access_token, body)
    if session.account then
        return message:callback_code(ACCOUNT_OFFLINE)
    end
    local account_params = {}
    local device_id = body.device_id
    --加载账号信息
    local account = login_dao:load_account(open_id)
    if not account then
        log_err("[LoginServlet][on_account_login_req] load account failed! open_id: {} token:{}", open_id, access_token)
        return message:callback_code(FRAME_FAILED)
    end
    if platform ~= PLATFORM_PASSWORD then
        --登录验证
        body.ip = session.ip
        local result = event_mgr:notify_listener("on_platform_login", platform, open_id, access_token, body, account_params, account:is_newbee())
        local ok, code, sdk_open_id, sdk_device_id = tunpack(result)
        local login_failed, login_code = qfailed(code, ok)
        if login_failed then
            log_err("[LoginServlet][on_account_login_req] verify failed! open_id: {} token:{} code:{}", open_id, access_token, login_code)
            return message:callback_code(login_code)
        end
        -- 三方信息
        open_id = sdk_open_id
        device_id = sdk_device_id
    end
    --创建账号
    if account:is_newbee() then
        if not account:create(access_token, device_id, account_params, channel) then
            log_err("[LoginServlet][on_account_login_req] open_id({}) create account failed!", open_id)
            return message:callback_code(FRAME_FAILED)
        end
        session.account = account
        event_mgr:notify_listener("on_account_create", account, device_id, session.ip, account_params.lang, account_params.dev_plat)
        log_info("[LoginServlet][on_account_login_req] newbee success! open_id: {}", open_id)
        account:pack2client(response)
        return
    end
    --密码验证
    if platform == PLATFORM_PASSWORD and account:get_token() ~= access_token then
        log_err("[LoginServlet][on_password_login] verify failed! open_id: {} token: {}-{}", open_id, access_token, account:get_token())
        return message:callback_code(VERIFY_FAILED)
    end
    session.account = account
    account:save_token(access_token)
    account:save_device_id(device_id)
    account:update_params(account_params)
    event_mgr:notify_listener("on_account_login", account:get_user_id(), open_id, device_id, session.ip, account_params.lang, account_params.dev_plat)
    account:pack2client(response)
    log_info("[LoginServlet][on_account_login_req] success! open_id: {}, response: {}", open_id, response)
end

--创建角色
function LoginServlet:on_player_create_req(session, message, body, response)
    local user_id, name = body.user_id, body.name
    log_debug("[LoginServlet][on_player_create_req] user({}) body({}) create player req11113!", user_id, body)
    local account = session.account
    if not account or account.user_id ~= user_id then
        log_err("[LoginServlet][on_player_create_req] user_id({}) need login!", user_id)
        return message:callback_code(ACCOUNT_OFFLINE)
    end
    if account:get_player_count() >= 3 then
        log_err("[LoginServlet][on_player_create_req] user_id({}) player num: {} limit!", user_id, account:get_player_count())
        return message:callback_code(PLAYER_NUM_LIMIT)
    end
    --检查名称合法性
    local ok, player_id = login_dao:check_player(user_id, name)
    log_debug("[LoginServlet][on_player_create_req] check_player ok:{} player_id:{}", ok, player_id)
    if not ok then
        return message:callback_code(player_id)
    end
    --创建角色
    if not login_dao:create_player(account:get_open_id(), player_id, body) then
        log_err("[LoginServlet][on_player_create_req] user_id({}) create player failed!", user_id)
        return message:callback_code(FRAME_FAILED)
    end
    log_info("[LoginServlet][on_player_create_req] user_id({}) create player {} success!", user_id, name)
    local pla_data = { facade = body.facade, player_id = player_id, name = name, gender = body.gender }
    event_mgr:notify_listener("on_player_create", user_id, player_id, pla_data)
    account:add_player(player_id, pla_data)
    response.player = pla_data
end

--选择角色
function LoginServlet:on_player_choose_req(session, message, body, response)
    local user_id, player_id = body.user_id, body.player_id
    log_debug("[LoginServlet][on_player_choose_req] user_id({}) player_id({}) choose req!", user_id, player_id)
    local account = session.account
    if not account then
        log_err("[LoginServlet][on_player_choose_req] user_id({}) need login!", user_id)
        return message:callback_code(ACCOUNT_OFFLINE)
    end
    local player = account:get_player(player_id)
    if not player then
        log_err("[LoginServlet][on_player_choose_req] user_id({}) player_id({}) player nit exist!", user_id, player_id)
        return message:callback_code(PLAYER_NOT_EXIST)
    end
    local fok, lobby = self:choose_gateway(player_id, response)
    log_debug("[LoginServlet][on_player_choose_req] choose gateway({})!", response)
    if not fok then
        log_err("[LoginServlet][on_player_choose_req] user_id({}) player_id({}) server uphold!", user_id, player_id)
        return message:callback_code(SERVER_UPHOLD)
    end
    account:save_lobby(lobby)
    log_info("[LoginServlet][on_player_choose_req] user_id({}) player_id({}) choose success!", user_id, player_id)
end

--删除角色
function LoginServlet:on_player_delete_req(session, message, body, response)
    local user_id, player_id = body.user_id, body.player_id
    log_debug("[LoginServlet][on_player_delete_req] user_id({}) player_id({}) delete req!", user_id, player_id)
    local account = session.account
    if not account or account:get_user_id() ~= user_id then
        log_err("[LoginServlet][on_player_delete_req] user_id({}) need login!", user_id)
        return message:callback_code(ACCOUNT_OFFLINE)
    end
    if not account:del_player(player_id) then
        log_err("[LoginServlet][on_player_delete_req] user_id({}) player_id({}) player not exist!", user_id, player_id)
        return message:callback_code(PLAYER_NOT_EXIST)
    end
    log_info("[LoginServlet][on_player_delete_req] user_id({}) player_id({}) delete success!", user_id, player_id)
end

--账号重登
function LoginServlet:on_account_reload_req(session, message, body, response)
    local open_id, token, device_id = body.openid, body.session, body.device_id
    log_debug("[LoginServlet][on_account_reload_req] openid({}) token({}) device_id({}) reload req!", open_id, token, device_id)
    if session.account then
        return message:callback_code(ACCOUNT_INLINE)
    end
    --验证token
    local account = login_dao:load_account(open_id)
    if not account then
        log_err("[LoginServlet][on_account_login_req] load account failed! open_id: {} token:{}", open_id, token)
        return message:callback_code(FRAME_FAILED)
    end
    if account:is_newbee() then
        log_err("[LoginServlet][on_account_reload_req] open_id({}) load account status failed!", open_id)
        return message:callback_code(FRAME_FAILED)
    end
    local otoken = account:get_token()
    local odevice_id = account:get_device_id()
    if token ~= otoken or device_id ~= odevice_id then
        log_err("[LoginServlet][on_account_reload_req] verify failed! open_id:{}, token:{}-{} device:{}-{}", open_id, token, otoken, device_id, odevice_id)
        return message:callback_code(VERIFY_FAILED)
    end
    session.account = account
    account:pack2client(response)
    log_info("[LoginServlet][on_account_reload_req] success! open_id: {}, user_id: {}", open_id, account:get_user_id())
end

--随机名字
function LoginServlet:on_random_name_req(session, message, body, response)
    response.name = guid_encode()
    log_debug("[LoginServlet][on_random_name_req] response: {}!", response)
end

function LoginServlet:choose_gateway(player_id, response)
    local region = quanta.region
    local lobby_id = login_mgr:find_server("lobby", region)
    if not lobby_id then
        return false
    end
    local gateway_id, gate_ip, gate_port = login_mgr:find_server("gateway", region)
    if not gateway_id then
        return false
    end
    local verify_code = quanta.now
    local ok, code = router_mgr:call_target(gateway_id, "rpc_update_verify_code", player_id, verify_code)
    if qfailed(code, ok) then
        log_err("[LoginServlet][choose_gateway] uplayer_id({}) update token failed!", player_id)
        return false
    end
    response.gate_ip = gate_ip
    response.lobby_id = lobby_id
    response.gate_port = gate_port
    response.player_id = player_id
    response.verify_code = verify_code
    return true, lobby_id
end

quanta.login_servlet = LoginServlet()

return LoginServlet
