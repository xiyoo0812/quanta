--login_mgr.lua
local log_warn          = logger.warn
local log_debug         = logger.debug

local event_mgr         = quanta.get("event_mgr")
local client_mgr        = quanta.get("client_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")


local Account           = import("login/account.lua")

local LoginMgr = singleton()

function LoginMgr:__init()
    -- 网络事件监听
    event_mgr:add_listener(self, "on_session_cmd")
    event_mgr:add_listener(self, "on_session_sync")
    event_mgr:add_listener(self, "on_session_error")
    event_mgr:add_listener(self, "on_socket_accept")
    -- cs协议监听
    protobuf_mgr:register(self, "NID_HEARTBEAT_REQ", "on_heartbeat_req")
end

--心跳协议
function LoginMgr:on_heartbeat_req(session, cmd_id, body, session_id)
    local sserial  = client_mgr:check_serial(session, body.serial)
    local data_res = { serial = sserial, time = quanta.now_ms }
    client_mgr:callback_by_id(session, cmd_id, data_res, session_id)
end

--客户端连上
function LoginMgr:on_socket_accept(session)
    log_debug("[LoginMgr][on_socket_accept] %s connected!", session.token)
end

--客户端数据同步
function LoginMgr:on_session_sync(session)
end

--客户端连接断开
function LoginMgr:on_session_error(session, token, err)
    log_warn("[LoginMgr][on_session_error] %s lost, because: %s!", token, err)
end

--客户端消息分发
function LoginMgr:on_session_cmd(session, service_type, cmd_id, body, session_id)
    event_mgr:notify_command(cmd_id, session, cmd_id, body, session_id)
end

function LoginMgr:load_account(open_id)
    local account = Account(open_id)
    if not account:load() then
        return
    end
    return account
end

quanta.login_mgr = LoginMgr()

return LoginMgr
