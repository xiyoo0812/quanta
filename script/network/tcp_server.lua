--tcp_server.lua

local log_err           = logger.err
local log_info          = logger.info
local signalquit        = signal.quit
local new_trace         = quanta.new_trace
local derive_port       = luabus.derive_port

local PROTO_PB          = luabus.proto_type.PB
local FLAG_REQ          = luabus.proto_flag.REQ
local RELAY_SELF        = luabus.relay_type.SELF

local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local socket_mgr        = quanta.get("socket_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local NETWORK_TIMEOUT   = quanta.enum("NetwkTime", "NETWORK_TIMEOUT")
local INDUCE            = quanta.enum("PortMode", "INDUCE")
local INCR              = quanta.enum("PortMode", "INCR")

local FRAME_FAILED      = protobuf_mgr:error_code("FRAME_FAILED")
local FRAME_PARAMS      = protobuf_mgr:error_code("FRAME_PARAMS")

local Message           = import("feature/message_pb.lua")

-- CS协议会话对象管理器
local TcpServer = class()
local prop = property(TcpServer)
prop:reader("ip", "")                   --监听ip
prop:reader("port", 0)                  --监听端口
prop:reader("sessions", {})             --会话列表
prop:reader("listener", nil)            --监听器
prop:reader("broad_token", nil)         --广播token
prop:reader("codec", nil)               --编解码器

function TcpServer:__init()
    self.codec = protobuf.pbcodec()
    --注册退出
    update_mgr:attach_quit(self)
end

function TcpServer:on_quit()
    if self.listener then
        self.listener.close()
        self.listener = nil
        self.codec = nil
        log_info("[TcpServer][on_quit]")
    end
end

function TcpServer:listen(ip, port, induce)
    -- 开启监听
    if not ip or not port then
        log_err("[TcpServer][listen] ip:{} or port:{} is nil", ip, port)
        signalquit()
        return
    end
    if induce == INDUCE then
        port = port + quanta.order - 1
    elseif induce == INCR then
        port = derive_port(port + quanta.order - 1, ip)
    end
    local listener = socket_mgr.listen(ip, port, PROTO_PB)
    if not listener then
        log_err("[TcpServer][setup] failed to listen: {}:{}", ip, port)
        signalquit()
        return
    end
    log_info("[TcpServer][listen] start listen at: {}:{}", ip, port)
    -- 安装回调
    listener.on_accept = function(session)
        self:on_socket_accept(session)
    end
    listener.on_error = function(stoken, err)
        log_err("[TcpServer][listen] error: {}:{}", stoken, err)
    end
    self.listener = listener
    self.ip, self.port = ip, port
    self.broad_token = listener.token
end

-- 分派协议数据
function TcpServer:dispatch_message(session, cmd_message)
    local message<close> = cmd_message
    -- 前置处理: 协议过滤/统计
    event_mgr:notify_trigger("on_recv_message", message)
    -- 参数检测
    if message.flag & FLAG_REQ ~= FLAG_REQ then
        return message:callback_code(FRAME_PARAMS)
    end
    -- 事件分发
    local cmd_id = message.cmd_id
    local nok = event_mgr:notify_command(cmd_id, session, message, message.request, message.response)
    if not nok then
        return message:callback_code(FRAME_FAILED)
    end
end

-- 连接回调
function TcpServer:on_socket_accept(session)
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
            log_err("[TcpServer][call_client] session lost! cmd_id:{}-({})", cmd_id, body)
            return false
        end
        local send_len = session.call_pb(session_id, cmd_id, flag, type, target_id, body)
        if send_len <= 0 then
            log_err("[TcpServer][call_client] call_pb failed! code:{}", send_len)
            return false
        end
        event_mgr:notify_trigger("on_send_message", cmd_id, body, send_len)
        return true
    end
    session.on_call_pb = function(recv_len, session_id, target_id, cmd_id, flag, body, err)
        if body then
            local message = Message(session, session_id, recv_len, body, cmd_id, flag, target_id)
            thread_mgr:fork(self.dispatch_message, new_trace(), self, session, message)
            return
        end
        log_err("[TcpServer][on_call_pb] pb cmd_id({}) decode field: {}!", cmd_id, err and err or "pb not define")
    end
    -- 绑定网络错误回调（断开）
    session.on_error = function(stoken, err)
        thread_mgr:fork(self.on_socket_error, nil, self, stoken, err)
    end
    --通知链接成功
    event_mgr:notify_listener("on_socket_accept", session)
end

-- 广播数据
function TcpServer:broadcast(cmd_id, data)
    socket_mgr.broadcast(self.codec, self.broad_token, 0, cmd_id, FLAG_REQ, RELAY_SELF, 0, 0, data)
end

-- 广播数据
function TcpServer:broadcast_groups(tokens, cmd_id, data)
    socket_mgr.broadgroup(self.codec, tokens, 0, cmd_id, FLAG_REQ, RELAY_SELF, 0, 0, data)
end

-- 发送数据
function TcpServer:call(session, cmd_id, data, target_id)
    return session.call_client(cmd_id, FLAG_REQ, RELAY_SELF, 0, target_id, data)
end

-- 关闭会话
function TcpServer:close_session(session)
    if self:remove_session(session.token) then
        session.close()
    end
end

-- 关闭会话
function TcpServer:close_session_by_token(token)
    local session = self.sessions[token]
    self:close_session(session)
end

-- 会话被关闭回调
function TcpServer:on_socket_error(token, err)
    log_err("[TcpServer][on_socket_error] session: {} lost, because: {}!", token, err)
    local session = self:remove_session(token)
    if session then
        event_mgr:notify_listener("on_socket_error", session, token, err)
    end
end

-- 添加会话
function TcpServer:add_session(session)
    local token = session.token
    if not self.sessions[token] then
        self.sessions[token] = session
    end
    return token
end

-- 移除会话
function TcpServer:remove_session(token)
    local session = self.sessions[token]
    if session then
        self.sessions[token] = nil
        return session
    end
end

-- 查询会话
function TcpServer:get_session(token)
    return self.sessions[token]
end

return TcpServer
