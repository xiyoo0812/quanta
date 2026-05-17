--kcp_server.lua
local log_err           = logger.err
local log_info          = logger.info
local signalquit        = signal.quit
local kcp_update        = kcp.update
local new_trace         = quanta.new_trace
local derive_port       = luabus.derive_port

local FLAG_REQ          = luabus.proto_flag.REQ

local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local NETWORK_TIMEOUT   = quanta.enum("NetwkTime", "NETWORK_TIMEOUT")
local INDUCE            = quanta.enum("PortMode", "INDUCE")
local INCR              = quanta.enum("PortMode", "INCR")

local FRAME_FAILED      = protobuf_mgr:error_code("FRAME_FAILED")
local FRAME_PARAMS      = protobuf_mgr:error_code("FRAME_PARAMS")

local Message           = import("feature/message_pb.lua")

-- CS协议会话对象管理器
local KcpServer = class()
local prop = property(KcpServer)
prop:reader("ip", "")                   --监听ip
prop:reader("port", 0)                  --监听端口
prop:reader("sessions", {})             --会话列表
prop:reader("listener", nil)            --监听器
prop:reader("codec", nil)               --编解码器

function KcpServer:__init()
    self.codec = protobuf.pbcodec()
    --注册退出
    update_mgr:attach_quit(self)
    --注册更新函数
    update_mgr:attach_frame(self)
end

function KcpServer:on_frame(clock_ms)
    kcp_update(clock_ms)
end

function KcpServer:on_quit()
    if self.listener then
        self.listener.close()
        self.listener = nil
        self.codec = nil
        log_info("[KcpServer][on_quit]")
    end
end

function KcpServer:listen(ip, port, induce)
    -- 开启监听
    if not ip or not port then
        log_err("[KcpServer][listen] ip:{} or port:{} is nil", ip, port)
        signalquit()
        return
    end
    if induce == INDUCE then
        port = port + quanta.order - 1
    elseif induce == INCR then
        port = derive_port(port + quanta.order - 1, ip)
    end
    local listener = kcp.listen(ip, port)
    if not listener then
        log_err("[KcpServer][setup] failed to listen: {}:{}", ip, port)
        signalquit()
        return
    end
    log_info("[KcpServer][listen] start listen at: {}:{}", ip, port)
    -- 安装回调
    listener.on_accept = function(session)
        self:on_socket_accept(session)
    end
    listener.on_error = function(stoken, err)
        log_err("[KcpServer][listen] error: {}:{}", stoken, err)
    end
    self.ip, self.port = ip, port
    self.listener = listener
end

-- 分派协议数据
function KcpServer:dispatch_message(session, cmd_message)
    local message<close> = cmd_message
    -- 前置处理: 协议过滤/统计
    event_mgr:notify_trigger("on_recv_kcp_message", message)
    -- 参数检测
    if message.flag & FLAG_REQ ~= FLAG_REQ then
        return message:callback_code(FRAME_PARAMS)
    end
    -- 事件分发
    local cmd_id = message.cmd_id
    local nok = event_mgr:notify_pb_message(cmd_id, session, message, message.request, message.response)
    if not nok then
        return message:callback_code(FRAME_FAILED)
    end
end

-- 连接回调
function KcpServer:on_socket_accept(session)
    -- 流控配置
    session.lc_cmd = {}
    session.fc_packet = 0
    session.fc_bytes  = 0
    session.last_fc_time = quanta.clock_ms
    session.set_codec(self.codec)
    -- 设置超时(心跳)
    session.set_timeout(NETWORK_TIMEOUT)
    -- 添加会话
    self:add_session(session)
    -- 绑定call回调
    session.call_client = function(cmd_id, flag, type, session_id, target_id, body)
        if session.token == 0 then
            log_err("[KcpServer][call_client] session lost! cmd_id:{}-({})", cmd_id, body)
            return false
        end
        local send_len = session.send_kcp(session_id, cmd_id, flag, type, target_id, body)
        if send_len <= 0 then
            log_err("[KcpServer][call_client] send_kcp failed! code:{}", send_len)
            return false
        end
        event_mgr:notify_trigger("on_send_kcp_message", cmd_id, body, send_len)
        return true
    end
    session.on_call = function(recv_len, session_id, target_id, cmd_id, flag, body, err)
        if body then
            local message = Message(session, session_id, recv_len, body, cmd_id, flag, target_id)
            thread_mgr:fork(self.dispatch_message, new_trace(), self, session, message)
            return
        end
        log_err("[KcpServer][on_call] pb cmd_id({}) decode field: {}!", cmd_id, err and err or "pb not define")
    end
    -- 绑定网络错误回调（断开）
    session.on_error = function(stoken, err)
        thread_mgr:fork(self.on_socket_error, nil, self, stoken, err)
    end
    --通知链接成功
    event_mgr:notify_listener("on_socket_accept", session)
end

-- 广播数据
function KcpServer:broadcast(cmd_id, data)
    for _, session in pairs(self.sessions) do
        session.call_client(cmd_id, FLAG_REQ, 0, 0, 0, data)
    end
end

-- 广播数据
function KcpServer:broadcast_groups(tokens, cmd_id, data)
    for _, token in pairs(tokens) do
        local session = self.sessions[token]
        if session then
            session.call_client(cmd_id, FLAG_REQ, 0, 0, 0, data)
        end
    end
end

-- 发送数据
function KcpServer:call(session, cmd_id, data, target_id)
    return session.call_client(cmd_id, FLAG_REQ, 0, 0, target_id, data)
end

-- 关闭会话
function KcpServer:close_session(session)
    if self:remove_session(session.token) then
        session.close()
    end
end

-- 关闭会话
function KcpServer:close_session_by_token(token)
    local session = self.sessions[token]
    self:close_session(session)
end

-- 会话被关闭回调
function KcpServer:on_socket_error(token, err)
    log_err("[KcpServer][on_socket_error] session: {} lost, because: {}!", token, err)
    local session = self:remove_session(token)
    if session then
        event_mgr:notify_listener("on_socket_error", session, token, err)
    end
end

-- 添加会话
function KcpServer:add_session(session)
    local token = session.token
    if not self.sessions[token] then
        self.sessions[token] = session
    end
    return token
end

-- 移除会话
function KcpServer:remove_session(token)
    local session = self.sessions[token]
    if session then
        self.sessions[token] = nil
        return session
    end
end

-- 查询会话
function KcpServer:get_session(token)
    return self.sessions[token]
end

return KcpServer
