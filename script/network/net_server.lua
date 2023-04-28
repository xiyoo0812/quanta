--net_server.lua
local lcrypt        = require("lcrypt")

local log_err           = logger.err
local log_info          = logger.info
local log_warn          = logger.warn
local log_fatal         = logger.fatal
local signalquit        = signal.quit
local qeval             = quanta.eval
local qxpcall           = quanta.xpcall
local env_status        = environ.status
local env_number        = environ.number
local b64_encode        = lcrypt.b64_encode
local b64_decode        = lcrypt.b64_decode
local lz4_encode        = lcrypt.lz4_encode
local lz4_decode        = lcrypt.lz4_decode

local event_mgr         = quanta.get("event_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")
local proxy_agent       = quanta.get("proxy_agent")

local FLAG_REQ          = quanta.enum("FlagMask", "REQ")
local FLAG_RES          = quanta.enum("FlagMask", "RES")
local FLAG_ZIP          = quanta.enum("FlagMask", "ZIP")
local FLAG_ENCRYPT      = quanta.enum("FlagMask", "ENCRYPT")
local NETWORK_TIMEOUT   = quanta.enum("NetwkTime", "NETWORK_TIMEOUT")

local out_press         = env_status("QUANTA_OUT_PRESS")
local out_encrypt       = env_status("QUANTA_OUT_ENCRYPT")
local flow_ctrl         = env_status("QUANTA_FLOW_CTRL")
local flow_cd           = env_number("QUANTA_FLOW_CTRL_CD")
local fc_package        = env_number("QUANTA_FLOW_CTRL_PACKAGE") / 1000
local fc_bytes          = env_number("QUANTA_FLOW_CTRL_BYTES") / 1000

-- CS协议会话对象管理器
local NetServer = class()
local prop = property(NetServer)
prop:reader("ip", "")                   --监听ip
prop:reader("port", 0)                  --监听端口
prop:reader("sessions", {})             --会话列表
prop:reader("session_type", "default")  --会话类型
prop:reader("session_count", 0)         --会话数量
prop:reader("listener", nil)            --监听器
prop:reader("command_cds", {})          --CMD定制CD
prop:accessor("codec", nil)             --编解码器

function NetServer:__init(session_type)
    self.session_type = session_type
    self.codec =  protobuf_mgr
end

--induce：根据 order 推导port
function NetServer:setup(ip, port, induce)
    -- 开启监听
    if not ip or not port then
        log_err("[NetServer][setup] ip:%s or port:%s is nil", ip, port)
        signalquit()
        return
    end
    local listen_proto_type = 1
    local socket_mgr = quanta.get("socket_mgr")
    local real_port = induce and (port + quanta.order - 1) or port
    self.listener = socket_mgr.listen(ip, real_port, listen_proto_type)
    if not self.listener then
        log_err("[NetServer][setup] failed to listen: %s:%d type=%d", ip, real_port, listen_proto_type)
        signalquit()
        return
    end
    self.ip, self.port = ip, real_port
    log_info("[NetServer][setup] start listen at: %s:%d type=%d", ip, real_port, listen_proto_type)
    -- 安装回调
    self.listener.on_accept = function(session)
        qxpcall(self.on_socket_accept, "on_socket_accept: %s", self, session)
    end
end

-- 连接回调
function NetServer:on_socket_accept(session)
    self:add_session(session)
    -- 流控配置
    session.fc_packet = 0
    session.fc_bytes  = 0
    session.last_fc_time = quanta.clock_ms
    -- 设置超时(心跳)
    session.set_timeout(NETWORK_TIMEOUT)
    -- 绑定call回调
    session.on_call_head = function(recv_len, cmd_id, flag, type, session_id, slice)
        session.fc_packet = session.fc_packet + 1
        session.fc_bytes  = session.fc_bytes  + recv_len
        proxy_agent:statistics("on_proto_recv", cmd_id, recv_len)
        qxpcall(self.on_socket_recv, "on_socket_recv: %s", self, session, cmd_id, flag, type, session_id, slice)
    end
    -- 绑定网络错误回调（断开）
    session.on_error = function(token, err)
        self:on_socket_error(token, err)
    end
    --初始化序号
    session.serial = 1
    session.serial_sync = 1
    session.command_times = {}
    --通知链接成功
    event_mgr:notify_listener("on_socket_accept", session)
end

function NetServer:write(session, cmd, data, session_id, flag)
    local body, cmd_id, pflag = self:encode(cmd, data, flag)
    if not body then
        log_fatal("[NetServer][write] encode failed! cmd_id:%s-(%s)", cmd, data)
        return false
    end
    session.serial = session.serial + 1
    if session_id > 0 then
        session_id = session_id & 0xffff
    end
    -- call lbus
    local send_len = session.call_head(cmd_id, pflag, 0, session_id, body, #body)
    if send_len <= 0 then
        log_err("[NetServer][write] call_head failed! code:%s", send_len)
        return false
    end
    proxy_agent:statistics("on_proto_send", cmd_id, send_len)
    return true
end

-- 广播数据
function NetServer:broadcast(cmd, data)
    local body, cmd_id, pflag = self:encode(cmd, data, FLAG_REQ)
    if not body then
        log_fatal("[NetServer][broadcast] encode failed! cmd_id:%s-(%s)", cmd_id, data)
        return false
    end
    for _, session in pairs(self.sessions) do
        local send_len = session.call_head(cmd_id, pflag, 0, 0, body, #body)
        if send_len > 0 then
            proxy_agent:statistics("on_proto_send", cmd_id, send_len)
        end
    end
    return true
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

function NetServer:encode(cmd, data, flag)
    local en_data, cmd_id = self.codec:encode(cmd, data)
    if not en_data then
        return
    end
    -- 加密处理
    if out_encrypt then
        en_data = b64_encode(en_data)
        flag = flag | FLAG_ENCRYPT
    end
    -- 压缩处理
    if out_press then
        en_data = lz4_encode(en_data)
        flag = flag | FLAG_ZIP
    end
    return en_data, cmd_id, flag
end

function NetServer:decode(cmd_id, slice, flag)
    local de_data = slice.string()
    if flag & FLAG_ZIP == FLAG_ZIP then
        --解压处理
        de_data = lz4_decode(de_data)
    end
    if flag & FLAG_ENCRYPT == FLAG_ENCRYPT then
        --解密处理
        de_data = b64_decode(de_data)
    end
    return self.codec:decode(cmd_id, de_data)
end

-- 配置指定cmd的cd
function NetServer:define_cmd_cd(cmd_id, cd_time)
    self.command_cds[cmd_id] = cd_time
end

-- 查找指定cmd的cdtime
function NetServer:get_cmd_cd(cmd_id)
    return self.command_cds[cmd_id] or flow_cd
end

-- 收到远程调用回调
function NetServer:on_socket_recv(session, cmd_id, flag, type, session_id, slice)
    local clock_ms = quanta.clock_ms
    local cmd_cd_time = self:get_cmd_cd(cmd_id)
    local command_times = session.command_times
    if command_times[cmd_id] and clock_ms - command_times[cmd_id] < cmd_cd_time then
        log_warn("[NetServer][on_socket_recv] session trigger cmd(%s) cd ctrl, will be drop.", cmd_id)
        --协议CD
        return
    end
    command_times[cmd_id] = clock_ms
    session.alive_time = quanta.now
    -- 解码
    local body, cmd_name = self:decode(cmd_id, slice, flag)
    if not body then
        log_warn("[NetServer][on_socket_rpc] decode failed! cmd_id:%s", cmd_id)
        return
    end
    if session_id == 0 or (flag & FLAG_REQ == FLAG_REQ) then
        local function dispatch_rpc_message(_session, typ, cmd, bd)
            local _<close> = qeval(cmd_name)
            local result = event_mgr:notify_listener("on_session_cmd", _session, typ, cmd, bd, session_id)
            if not result[1] then
                log_err("[NetServer][on_socket_recv] on_session_cmd failed! cmd_id:%s", cmd_id)
            end
        end
        thread_mgr:fork(dispatch_rpc_message, session, type, cmd_id, body)
        return
    end
    --异步回执
    thread_mgr:response(session_id, true, body)
end

--检查序列号
function NetServer:check_serial(session, cserial)
    local sserial = session.serial
    if cserial and cserial ~= session.serial_sync then
        log_warn("[NetServer][check_serial] serial number(%s-%s) error", cserial, session.serial_sync)
        event_mgr:notify_listener("on_session_sync", session)
    end
    session.serial_sync = sserial

    -- 流量控制检测
    if flow_ctrl then
        -- 达到检测周期
        local cur_time = quanta.clock_ms
        local escape_time = cur_time - session.last_fc_time
        -- 检查是否超过配置
        if session.fc_packet / escape_time > fc_package or session.fc_bytes / escape_time > fc_bytes then
            log_warn("[NetServer][check_serial] session trigger package or bytes flowctrl line, will be closed.")
            self:close_session(session)
        end
        session.fc_packet = 0
        session.fc_bytes  = 0
        session.last_fc_time = cur_time
    end
    return sserial
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
            event_mgr:notify_listener("on_session_error", session, token, err)
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
