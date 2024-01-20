--login_mgr.lua
local log_warn          = logger.warn
local log_debug         = logger.debug

local event_mgr         = quanta.get("event_mgr")
local client_mgr        = quanta.get("client_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local FRAME_UPHOLD      = protobuf_mgr:error_code("FRAME_UPHOLD")

local LoginMgr = singleton()

function LoginMgr:__init()
    -- 网络事件监听
    event_mgr:add_listener(self, "on_socket_cmd")
    event_mgr:add_listener(self, "on_socket_error")
    event_mgr:add_listener(self, "on_socket_accept")
    -- cs协议监听
    protobuf_mgr:register(self, "NID_HEARTBEAT_REQ", "on_heartbeat_req")
end

--心跳协议
function LoginMgr:on_heartbeat_req(session, cmd_id, body, session_id)
    client_mgr:check_flow(session)
    client_mgr:callback_by_id(session, cmd_id, { time = quanta.now_ms, error_code = 0 }, session_id)
end

--客户端连上
function LoginMgr:on_socket_accept(session)
    log_debug("[LoginMgr][on_socket_accept] {} connected!", session.token)
end

--客户端连接断开
function LoginMgr:on_socket_error(session, token, err)
    log_debug("[LoginMgr][on_socket_error] {} lost, because: {}!", token, err)
    local account = session.account
    if account then
        log_debug("[LoginMgr][on_socket_error] (t:{}-o:{}-u:{}) lost, because: {}!", token, account.open_id, account.user_id, err)
    end
end

--客户端消息分发
function LoginMgr:on_socket_cmd(session, service_type, cmd_id, body, session_id)
    local result = event_mgr:notify_listener("on_proto_filter", cmd_id, service_type)
    if result[1] and result[2] then
        log_warn("[LoginMgr][on_socket_cmd] on_proto_filter false, cmd_id={}", cmd_id)
        client_mgr:callback_errcode(session, cmd_id, FRAME_UPHOLD, session_id)
        return
    end
    event_mgr:notify_command(cmd_id, session, cmd_id, body, session_id)
end

quanta.login_mgr = LoginMgr()

return LoginMgr
