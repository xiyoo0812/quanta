--net_server.lua
local encrypt       = require("encrypt")

local log_err       = logger.err
local log_info      = logger.info
local qxpcall       = quanta.xpcall
local env_status    = environ.status
local env_number    = environ.number

local event_mgr     = quanta.event_mgr
local thread_mgr    = quanta.thread_mgr
local protobuf_mgr  = quanta.protobuf_mgr
local perfeval_mgr  = quanta.perfeval_mgr
local statis_mgr    = quanta.statis_mgr

local FlagMask      = enum("FlagMask")
local NetwkTime     = enum("NetwkTime")

local out_press     = env_status("QUANTA_OUT_PRESS")
local out_encrypt   = env_status("QUANTA_OUT_ENCRYPT")
local flow_ctrl     = env_status("QUANTA_FLOW_CTRL")
local flow_cd       = env_number("QUANTA_FLOW_CTRL_CD")
local fc_package    = env_number("QUANTA_FLOW_CTRL_PACKAGE") / 1000
local fc_bytes      = env_number("QUANTA_FLOW_CTRL_BYTES") / 1000

-- Dx协议会话对象管理器
local NetServer = class()
local prop = property(NetServer)
prop:accessor("sessions", {})               --会话列表
prop:accessor("session_type", "default")    --会话类型
prop:accessor("session_count", 0)           --会话数量
prop:accessor("listener", nil)              --监听器
prop:accessor("decoder", nil)               --解码函数
prop:accessor("encoder", nil)               --编码函数
prop:accessor("port", 0)                    --监听端口
prop:accessor("ip", "")                     --监听ip

function NetServer:__init(session_type)
    self.session_type = session_type
end

--induce：根据index推导port
function NetServer:setup(ip, port, induce)
    -- 开启监听
    if not ip or not port then
        log_err("[NetServer][setup] ip:%s or port:%s is nil", ip, port)
        os.exit(1)
    end
    local listen_proto_type = 1
    local socket_mgr = quanta.socket_mgr
    local real_port = induce and (port + quanta.index - 1) or port
    self.listener = socket_mgr.listen(ip, real_port, listen_proto_type)
    if not self.listener then
        log_err("[NetServer][setup] failed to listen: %s:%d type=%d", ip, real_port, listen_proto_type)
        os.exit(1)
    end
    self.ip, self.port = ip, real_port
    log_info("[NetServer][setup] start listen at: %s:%d type=%d", ip, real_port, listen_proto_type)
    -- 安装回调
    self.listener.on_accept = function(session)
        qxpcall(self.on_session_accept, "on_dx_accept: %s", self, session)
    end


end

-- 连接回调
function NetServer:on_session_accept(session)
    --log_debug("[on_session_accept]: token:%s, ip:%s", session.token, session.ip)
    self:add_session(session)
    -- 流控配置
    session.fc_packet = 0
    session.fc_bytes  = 0
    session.last_fc_time = quanta.now_ms
    -- 设置超时(心跳)
    session.set_timeout(NetwkTime.NETWORK_TIMEOUT)
    -- 绑定call回调
    session.on_call_dx = function(recv_len, cmd_id, flag, session_id, data)
        session.fc_packet = session.fc_packet + 1
        session.fc_bytes  = session.fc_bytes  + recv_len
        statis_mgr:statis_notify("on_dx_recv", cmd_id, recv_len)
        qxpcall(self.on_call_dx, "on_call_dx: %s", self, session, cmd_id, flag, session_id, data)
    end
    -- 绑定网络错误回调（断开）
    session.on_error = function(err)
        qxpcall(self.on_session_err, "on_session_err: %s", self, session)
    end
    --初始化序号
    session.serial = 0
    session.serial_sync = 0
    session.command_times = {}
    --通知链接成功
    event_mgr:notify_listener("on_session_accept", session)
end

function NetServer:write(session, cmd_id, data, session_id, flag)
    local body, pflag = self:encode(cmd_id, data, flag)
    if not body then
        log_err("[NetServer][write] encode failed! cmd_id:%s", cmd_id)
        return false
    end
    session.serial = session.serial + 1
    -- call lbus
    local send_len = session.call_dx(cmd_id, pflag, session_id or 0, body)
    if send_len > 0 then
        statis_mgr:statis_notify("on_dx_send", cmd_id, send_len)
        return true
    end
    log_err("[NetServer][write] call_dx failed! code:%s", send_len)
    return false
end

-- 发送数据
function NetServer:send_dx(session, cmd_id, data, session_id)
    return self:write(session, cmd_id, data, session_id, FlagMask.REQ)
end

-- 回调数据
function NetServer:callback_dx(session, cmd_id, data, session_id)
    return self:write(session, cmd_id, data, session_id, FlagMask.RES)
end

-- 发起远程调用
function NetServer:call_dx(session, cmd_id, data)
    local session_id = thread_mgr:build_session_id()
    if not self:write(session, cmd_id, data, session_id, FlagMask.REQ) then
        return false
    end
    return thread_mgr:yield(session_id, cmd_id, NetwkTime.RPC_CALL_TIMEOUT)
end

function NetServer:encode(cmd_id, data, flag)
    local encode_data
    if self.encoder then
        encode_data = self.encoder(cmd_id, data)
    else
        encode_data = protobuf_mgr:encode(cmd_id, data)
    end
    if encode_data then
        -- 加密处理
        if out_encrypt then
            encode_data = encrypt.encrypt(encode_data)
            flag = flag | FlagMask.ENCRYPT
        end
        -- 压缩处理
        if out_press then
            encode_data = encrypt.quick_zip(encode_data)
            flag = flag | FlagMask.QZIP
        end
    end
    return encode_data, flag
end

function NetServer:decode(cmd_id, data, flag)
    local de_data, cmd_name
    if self.decoder then
        de_data, cmd_name = self.decoder(cmd_id, data)
    else
        de_data, cmd_name = protobuf_mgr:decode(cmd_id, data)
    end
    if de_data then
        --解压处理
        if flag & FlagMask.QZIP == FlagMask.QZIP then
            de_data = encrypt.quick_unzip(de_data)
        end
        --解密处理
        if flag & FlagMask.ENCRYPT == FlagMask.ENCRYPT then
            de_data = encrypt.decrypt(de_data)
        end
    end
    return de_data, cmd_name
end

-- 收到远程调用回调
function NetServer:on_call_dx(session, cmd_id, flag, session_id, data)
    local now_ms = quanta.now_ms
    local command_times = session.command_times
    if command_times[cmd_id] and now_ms - command_times[cmd_id] < flow_cd then
        --协议CD
        return
    end
    command_times[cmd_id] = now_ms
    session.alive_time = quanta.now
    -- 解码
    local body, cmd_name = self:decode(cmd_id, data, flag)
    if not body then
        return
    end
    if session_id == 0 or (flag & FlagMask.REQ == FlagMask.REQ) then
        local function dispatch_rpc_message(_session, cmd, bd)
            local eval = perfeval_mgr:begin_eval(cmd_name)
            local result = event_mgr:notify_listener("on_session_cmd", _session, cmd, bd, session_id)
            if not result[1] then
                log_err("[NetServer][on_call_dx] on_session_cmd failed! cmd_id:%s", cmd_id)
            end
            perfeval_mgr:end_eval(eval)
        end
        thread_mgr:fork(dispatch_rpc_message, session, cmd_id, body)
        return
    end
    --异步回执
    thread_mgr:response(session_id, true, body)
end

--检查序列号
function NetServer:check_serial(session, cserial)
    local sserial = session.serial
    if cserial and cserial ~= session.serial_sync then
        event_mgr:notify_listener("on_session_sync", session)
    end
    session.serial_sync = sserial

    -- 流量控制检测
    if flow_ctrl then
        -- 达到检测周期
        local cur_time = quanta.now_ms
        local escape_time = cur_time - session.last_fc_time
        -- 检查是否超过配置
        if session.fc_packet / escape_time > fc_package or session.fc_bytes / escape_time > fc_bytes then
            self:close_session(session)
        end
        session.fc_packet = 0
        session.fc_bytes  = 0
        session.last_fc_time = cur_time
    end
    return sserial
end

-- 关闭会话
-- @param session: 会话对象
function NetServer:close_session(session)
    if session then
        session.close()
    end
end

-- 关闭会话
-- @param token: 目标会话的token
function NetServer:close_session_by_token(token)
    local session = self.sessions[token]
    self:close_session(session)
end

-- 会话被关闭回调
function NetServer:on_session_err(session, err)
    thread_mgr:fork(function()
        event_mgr:notify_listener("on_session_err", session, err)
    end)
    self:remove_session(session)
end

-- 添加会话
function NetServer:add_session(session)
    self.sessions[session.token] = session
    self.session_count = self.session_count + 1
    statis_mgr:statis_notify("on_dx_conn_update", self.session_type, self.session_count)
end

-- 移除会话
function NetServer:remove_session(session)
    self.sessions[session.token] = nil
    self.session_count = self.session_count - 1
    statis_mgr:statis_notify("on_dx_conn_update", self.session_type, self.session_count)
end

-- 查询会话
function NetServer:get_session_by_token(token)
    return self.sessions[token];
end

return NetServer
