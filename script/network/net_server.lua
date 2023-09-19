--net_server.lua

local log_err           = logger.err
local log_info          = logger.info
local log_warn          = logger.warn
local log_fatal         = logger.fatal
local signalquit        = signal.quit
local qeval             = quanta.eval
local qxpcall           = quanta.xpcall

local proto_pb          = luabus.eproto_type.pb

local event_mgr         = quanta.get("event_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local socket_mgr        = quanta.get("socket_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")
local proxy_agent       = quanta.get("proxy_agent")

local FLAG_REQ          = quanta.enum("FlagMask", "REQ")
local FLAG_RES          = quanta.enum("FlagMask", "RES")
local NETWORK_TIMEOUT   = quanta.enum("NetwkTime", "NETWORK_TIMEOUT")
local FAST_MS           = quanta.enum("PeriodTime", "FAST_MS")
local SECOND_MS         = quanta.enum("PeriodTime", "SECOND_MS")
local TOO_FAST          = quanta.enum("KernCode", "TOO_FAST")

local FLOW_CTRL         = environ.status("QUANTA_FLOW_CTRL")
local FC_PACKETS        = environ.number("QUANTA_FLOW_CTRL_PACKAGE")
local FC_BYTES          = environ.number("QUANTA_FLOW_CTRL_BYTES")

-- CS协议会话对象管理器
local NetServer = class()
local prop = property(NetServer)
prop:reader("ip", "")                   --监听ip
prop:reader("port", 0)                  --监听端口
prop:reader("sessions", {})             --会话列表
prop:reader("session_type", "default")  --会话类型
prop:reader("session_count", 0)         --会话数量
prop:reader("listener", nil)            --监听器
prop:reader("broadcast_token", nil)     --监听器
prop:reader("codec", nil)               --编解码器

function NetServer:__init(session_type)
    self.session_type = session_type
    self.codec = protobuf.pbcodec("ncmd_cs", "ncmd_cs.NCmdId")
end

--induce：根据 order 推导port
function NetServer:setup(ip, port, induce)
    -- 开启监听
    if not ip or not port then
        log_err("[NetServer][setup] ip:%s or port:%s is nil", ip, port)
        signalquit()
        return
    end
    local real_port = induce and (port + quanta.order - 1) or port
    local listener = socket_mgr.listen(ip, real_port, proto_pb)
    if not listener then
        log_err("[NetServer][setup] failed to listen: %s:%d", ip, real_port)
        signalquit()
        return
    end
    log_info("[NetServer][setup] start listen at: %s:%d", ip, real_port)
    -- 安装回调
    listener.set_codec(self.codec)
    listener.on_accept = function(session)
        qxpcall(self.on_socket_accept, "on_socket_accept: %s", self, session)
    end
    self.listener = listener
    self.ip, self.port = ip, real_port
    self.broadcast_token = listener.token
end

-- 连接回调
function NetServer:on_socket_accept(session)
    -- 流控配置
    session.lc_crc = 0
    session.lc_time = 0
    session.fc_packet = 0
    session.fc_bytes  = 0
    session.last_fc_time = quanta.clock_ms
    -- 设置超时(心跳)
    session.set_timeout(NETWORK_TIMEOUT)
    -- 添加会话
    self:add_session(session)
    -- 绑定call回调
    session.call_client = function(cmd_id, flag, session_id, body)
        local send_len = session.call_pb(session_id, cmd_id, flag, 0, 0, body)
        if send_len <= 0 then
            log_err("[NetServer][call_client] call_pb failed! code:%s", send_len)
            return false
        end
        return true
    end
    session.on_call_pb = function(recv_len, session_id, cmd_id, flag, type, crc8, body)
        local now_ms = quanta.now_ms
        if session.lc_crc == crc8 and now_ms - session.lc_time < FAST_MS then
            self:callback_errcode(session, cmd_id, TOO_FAST, session_id)
            return
        end
        session.lc_crc = crc8
        session.lc_time = now_ms
        if FLOW_CTRL then
            session.fc_packet = session.fc_packet + 1
            session.fc_bytes  = session.fc_bytes  + recv_len
        end
        proxy_agent:statistics("on_proto_recv", cmd_id, recv_len)
        qxpcall(self.on_socket_recv, "on_socket_recv: %s", self, session, cmd_id, flag, type, session_id, body)
    end
    -- 绑定网络错误回调（断开）
    session.on_error = function(stoken, err)
        self:on_socket_error(stoken, err)
    end
    --通知链接成功
    event_mgr:notify_listener("on_socket_accept", session)
end

function NetServer:write(session, cmd, data, session_id, flag)
    if session.token == 0 then
        log_fatal("[NetServer][write] session lost! cmd_id:%s-(%s)", cmd, data)
        return false
    end
    return session.call_client(cmd, flag, session_id, data)
end

-- 广播数据
function NetServer:broadcast(cmd_id, data)
    socket_mgr.broadcast(self.codec, self.broadcast_token, cmd_id, FLAG_REQ, 0, 0, data)
end

-- 广播数据
function NetServer:broadcast_groups(tokens, cmd_id, data)
    socket_mgr.broadgroup(self.codec, tokens, cmd_id, FLAG_REQ, 0, 0, data)
end

-- 发送数据
function NetServer:send(session, cmd_id, data)
    return self:write(session, cmd_id, data, 0, FLAG_REQ)
end

-- 回调数据
function NetServer:callback(session, cmd_id, data, session_id)
    return self:write(session, cmd_id, data, session_id or 0, FLAG_RES)
end

-- 回调数据
function NetServer:callback_by_id(session, cmd_id, data, session_id)
    local callback_id = protobuf_mgr:callback_id(cmd_id)
    return self:write(session, callback_id, data, session_id or 0, FLAG_RES)
end

-- 回复错误码
function NetServer:callback_errcode(session, cmd_id, code, session_id)
    local data = { error_code = code }
    local callback_id = protobuf_mgr:callback_id(cmd_id)
    return self:write(session, callback_id, data, session_id or 0, FLAG_RES)
end

-- 收到远程调用回调
function NetServer:on_socket_recv(session, cmd_id, flag, type, session_id, body)
    if session_id == 0 or (flag & FLAG_REQ == FLAG_REQ) then
        local function dispatch_rpc_message(_session, typ, cmd, cbody)
            local _<close> = qeval(cmd_id)
            local result = event_mgr:notify_listener("on_socket_cmd", _session, typ, cmd, cbody, session_id)
            if not result[1] then
                log_err("[NetServer][on_socket_recv] on_socket_cmd failed! cmd_id:%s", cmd_id)
            end
        end
        thread_mgr:fork(dispatch_rpc_message, session, type, cmd_id, body)
        return
    end
    --异步回执
    thread_mgr:response(session_id, true, body)
end

--检查序列号
function NetServer:check_flow(session)
    -- 流量控制检测
    if FLOW_CTRL then
        -- 达到检测周期
        local cur_time = quanta.clock_ms
        local escape = cur_time - session.last_fc_time
        if escape > SECOND_MS then
            -- 检查是否超过配置
            if session.fc_packet > (FC_PACKETS * escape // SECOND_MS) or session.fc_bytes > FC_BYTES then
                log_warn("[NetServer][check_flow] session trigger package or bytes flowctrl line, will be closed.")
                self:close_session(session)
            end
            session.fc_packet = 0
            session.fc_bytes  = 0
            session.last_fc_time = cur_time
        end
    end
end

-- 关闭会话
function NetServer:close_session(session)
    if self:remove_session(session.token) then
        session.close()
    end
end

-- 关闭会话
function NetServer:close_session_by_token(token)
    local session = self.sessions[token]
    self:close_session(session)
end

-- 会话被关闭回调
function NetServer:on_socket_error(token, err)
    thread_mgr:fork(function()
        local session = self:remove_session(token)
        if session then
            event_mgr:notify_listener("on_socket_error", session, token, err)
        end
    end)
end

-- 添加会话
function NetServer:add_session(session)
    local token = session.token
    if not self.sessions[token] then
        self.sessions[token] = session
        self.session_count = self.session_count + 1
        proxy_agent:statistics("on_conn_update", self.session_type, self.session_count)
    end
    return token
end

-- 移除会话
function NetServer:remove_session(token)
    local session = self.sessions[token]
    if session then
        self.sessions[token] = nil
        self.session_count = self.session_count - 1
        proxy_agent:statistics("on_conn_update", self.session_type, self.session_count)
        return session
    end
end

-- 查询会话
function NetServer:get_session_by_token(token)
    return self.sessions[token]
end

return NetServer
