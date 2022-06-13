--login_mgr.lua

local event_mgr             = quanta.get("event_mgr")
local client_mgr            = quanta.get("client_mgr")

local NCmdId                = ncmd_cs.NCmdId
local HEARTBEAT_RES         = NCmdId.NID_HEARTBEAT_RES

local LoginMgr = singleton()
local prop = property()
prop:reader("client_mgr", nil)      --会话列表

function LoginMgr:__init(session_type)
    -- 网络事件监听
    event_mgr:add_listener(self, "on_session_cmd")
    event_mgr:add_listener(self, "on_session_sync")
    event_mgr:add_listener(self, "on_session_error")
end

--心跳协议
function LoginMgr:on_heartbeat_req(session, body, session_id)
    local sserial  = self.client_mgr:check_serial(session, body.serial)
    local data_res = { serial = sserial, time = quanta.now }
    client_mgr:callback(session, HEARTBEAT_RES, data_res, session_id)
end

--客户端数据同步
function LoginMgr:on_session_sync(session)
end

--客户端连接断开
function LoginMgr:on_session_error(session, token, err)
end

--客户端消息分发
function LoginMgr:on_session_cmd(session, service_type, cmd_id, body, session_id)
    event_mgr:notify_command(cmd_id, session, body, session_id)
end

quanta.login_mgr = LoginMgr()

return LoginMgr
