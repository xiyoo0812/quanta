--tcp_server.lua

local log_err           = logger.err
local log_info          = logger.info
local log_warn          = logger.warn
local signalquit        = signal.quit
local qdefer            = quanta.defer
local qxpcall           = quanta.xpcall
local new_trace         = quanta.new_trace
local derive_port       = luabus.derive_port

local PROTO_PB          = luabus.eproto_type.PB

local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local socket_mgr        = quanta.get("socket_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local FLAG_REQ          = quanta.enum("FlagMask", "REQ")
local FLAG_RES          = quanta.enum("FlagMask", "RES")
local NETWORK_TIMEOUT   = quanta.enum("NetwkTime", "NETWORK_TIMEOUT")
local SLOW_MS           = quanta.enum("PeriodTime", "SLOW_MS")
local SECOND_MS         = quanta.enum("PeriodTime", "SECOND_MS")
local TOO_FAST          = quanta.enum("KernCode", "TOO_FAST")

local FLOW_CTRL         = environ.status("QUANTA_FLOW_CTRL")
local FC_PACKETS        = environ.number("QUANTA_FLOW_CTRL_PACKAGE")
local FC_BYTES          = environ.number("QUANTA_FLOW_CTRL_BYTES")

-- CS协议会话对象管理器
local TcpServer = class()
local prop = property(TcpServer)
prop:reader("ip", "")                   --监听ip
prop:reader("port", 0)                  --监听端口
prop:reader("sessions", {})             --会话列表
prop:reader("session_type", "default")  --会话类型
prop:reader("session_count", 0)         --会话数量
prop:reader("listener", nil)            --监听器
prop:reader("broad_token", nil)         --广播token
prop:reader("codec", nil)               --编解码器

function TcpServer:__init(session_type)
    self.session_type = session_type
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

--induce：根据 order 推导port
function TcpServer:listen(ip, port, induce)
    -- 开启监听
    if not ip or not port then
        log_err("[TcpServer][listen] ip:{} or port:{} is nil", ip, port)
        signalquit()
        return
    end
    local induce_port = induce and (port + quanta.order - 1) or port
    local real_port = derive_port(induce_port, ip)
    local listener = socket_mgr.listen(ip, real_port, PROTO_PB)
    if not listener then
        log_err("[TcpServer][setup] failed to listen: {}:{}", ip, real_port)
        signalquit()
        return
    end
    log_info("[TcpServer][listen] start listen at: {}:{}", ip, real_port)
    -- 安装回调
    listener.on_accept = function(session)
        qxpcall(self.on_socket_accept, "on_socket_accept: {}", self, session)
    end
    listener.on_error = function(stoken, err)
        log_err("[TcpServer][listen] error: {}:{}", stoken, err)
    end
    self.listener = listener
    self.ip, self.port = ip, real_port
    self.broad_token = listener.token
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
    session.call_client = function(cmd_id, flag, ctype, session_id, body)
        local send_len = session.call_pb(session_id, cmd_id, flag, ctype or 0, 0, body)
        if send_len <= 0 then
            log_err("[TcpServer][call_client] call_pb failed! code:{}", send_len)
            return false
        end
        return true
    end
    session.on_call_pb = function(recv_len, session_id, cmd_id, flag, type, crc8, body, err)
        --消息 hook
        local hook<close> = qdefer()
        event_mgr:execute_hook("on_scmd_recv", hook, cmd_id, body)
        -- 限流+CRC校验
        local now_ms = quanta.now_ms
        local cmd = session.lc_cmd[cmd_id]
        if crc8 > 0 and cmd and cmd.crc8 == crc8 and now_ms - cmd.time < SLOW_MS then
            self:callback_errcode(session, cmd_id, TOO_FAST, session_id)
            return
        end
        session.lc_cmd[cmd_id] = { time = now_ms, crc8 = crc8, type = type }
        if FLOW_CTRL then
            session.fc_packet = session.fc_packet + 1
            session.fc_bytes  = session.fc_bytes  + recv_len
        end
        qxpcall(self.on_socket_recv, "on_socket_recv:{}", self, session, cmd_id, flag, type, session_id, body, err)
    end
    -- 绑定网络错误回调（断开）
    session.on_error = function(stoken, err)
        self:on_socket_error(stoken, err)
    end
    --通知链接成功
    event_mgr:notify_listener("on_socket_accept", session)
end

function TcpServer:write(session, cmd, data, session_id, flag, type)
    if session.token == 0 then
        log_err("[TcpServer][write] session lost! cmd_id:{}-({})", cmd, data)
        return false
    end
    local hook<close> = qdefer()
    event_mgr:execute_hook("on_scmd_send", hook, cmd, data)
    return session.call_client(cmd, flag, type or 0, session_id, data)
end

-- 广播数据
function TcpServer:broadcast(cmd_id, data)
    socket_mgr.broadcast(self.codec, self.broad_token, 0, cmd_id, FLAG_REQ, 0, 0, data)
end

-- 广播数据
function TcpServer:broadcast_groups(tokens, cmd_id, data)
    socket_mgr.broadgroup(self.codec, tokens, 0, cmd_id, FLAG_REQ, 0, 0, data)
end

-- 发送数据
function TcpServer:send(session, cmd_id, data)
    return self:write(session, cmd_id, data, 0, FLAG_REQ)
end

-- 回调数据
function TcpServer:callback(session, cmd_id, data, session_id)
    return self:write(session, cmd_id, data, session_id or 0, FLAG_RES)
end

-- 回调数据
function TcpServer:callback_by_id(session, cmd_id, data, session_id)
    local callback_id = protobuf_mgr:callback_id(cmd_id)
    if not callback_id then
        return false
    end
    local cmd = session.lc_cmd[cmd_id]
    return self:write(session, callback_id, data, session_id or 0, FLAG_RES, cmd.type)
end

-- 回复错误码
function TcpServer:callback_errcode(session, cmd_id, code, session_id)
    local callback_id = protobuf_mgr:callback_id(cmd_id)
    if not callback_id then
        return false
    end
    local cmd = session.lc_cmd[cmd_id]
    local data = { error_code = code }
    return self:write(session, callback_id, data, session_id or 0, FLAG_RES, cmd.type)
end

-- 收到远程调用回调
function TcpServer:on_socket_recv(session, cmd_id, flag, type, session_id, body, err)
    if session_id == 0 or (flag & FLAG_REQ == FLAG_REQ) then
        local function dispatch_rpc_message(socket, typ, cmd, cbody)
            if cbody then
                local result = event_mgr:notify_listener("on_socket_cmd", socket, typ, cmd, cbody, session_id)
                if not result[1] then
                    log_err("[TcpServer][on_socket_recv] on_socket_cmd failed! cmd_id:{}", cmd)
                end
            else
                log_warn("[TcpServer][on_socket_recv] pb cmd_id({}) decode field: {}!", cmd, err and err or "pb not define")
            end
        end
        thread_mgr:fork(dispatch_rpc_message, new_trace(), session, type, cmd_id, body)
        return
    end
    --异步回执
    thread_mgr:response(session_id, true, body)
end

--检查序列号
function TcpServer:check_flow(session)
    -- 流量控制检测
    if FLOW_CTRL then
        -- 达到检测周期
        local cur_time = quanta.clock_ms
        local escape = cur_time - session.last_fc_time
        if escape > SECOND_MS then
            -- 检查是否超过配置
            local is_over_packets = session.fc_packet > (FC_PACKETS * escape // SECOND_MS)
            local is_over_bytes = session.fc_bytes > (FC_BYTES * escape // SECOND_MS)
            if is_over_packets or is_over_bytes then
                log_warn("[TcpServer][check_flow] session trigger package({}) or bytes({}) flowctrl line, will be closed.", is_over_packets, is_over_bytes)
                self:close_session(session)
            end
            session.fc_packet = 0
            session.fc_bytes  = 0
            session.last_fc_time = cur_time
        end
    end
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
    thread_mgr:fork(function()
        local session = self:remove_session(token)
        if session then
            event_mgr:notify_listener("on_socket_error", session, token, err)
        end
    end)
end

-- 添加会话
function TcpServer:add_session(session)
    local token = session.token
    if not self.sessions[token] then
        self.sessions[token] = session
        self.session_count = self.session_count + 1
    end
    return token
end

-- 移除会话
function TcpServer:remove_session(token)
    local session = self.sessions[token]
    if session then
        self.sessions[token] = nil
        self.session_count = self.session_count - 1
        return session
    end
end

-- 查询会话
function TcpServer:get_session_by_token(token)
    return self.sessions[token]
end

return TcpServer
