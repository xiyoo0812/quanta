--tcp_client.lua

local log_err           = logger.err
local log_warn          = logger.warn
local lnext_id          = luakit.next_id
local make_timer        = quanta.make_timer
local make_functer      = quanta.make_functer

local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local socket_mgr        = quanta.get("socket_mgr")
local thread_mgr        = quanta.get("thread_mgr")

local PROTO_PB          = luabus.proto_type.PB
local FLAG_REQ          = luabus.proto_flag.REQ
local FLAG_BAD          = luabus.proto_flag.BAD
local FLAG_UNREACH      = luabus.proto_flag.UNREACH

local RELAY_SELF        = luabus.relay_type.SELF

local FAST_MS           = quanta.enum("PeriodTime", "FAST_MS")
local SECOND_MS         = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_5_MS       = quanta.enum("PeriodTime", "SECOND_5_MS")
local CONNECT_TIMEOUT   = quanta.enum("NetwkTime", "CONNECT_TIMEOUT")
local RPC_CALL_TIMEOUT  = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local UNREACHABLE       = quanta.enum("KernCode", "UNREACHABLE")
local PARAM_ERROR       = quanta.enum("KernCode", "PARAM_ERROR")

local Message           = import("feature/message_pb.lua")

local TcpClient = class()
local prop = property(TcpClient)
prop:reader("ip", nil)
prop:reader("port", nil)
prop:reader("codec", nil)
prop:reader("timer", nil)
prop:reader("alive", false)
prop:reader("serial", 0)
prop:reader("diff_time", 0)
prop:reader("functor", nil)
prop:reader("socket", nil)          --连接成功对象
prop:reader("wait_list", {})        --等待协议列表

function TcpClient:__init(ip, port)
    self.ip = ip
    self.port = port
    self.timer = make_timer()
    self.codec = protobuf.pbcodec()
    self.functor = make_functer("check_alive", CONNECT_TIMEOUT)
end

function TcpClient:start()
    update_mgr:attach_quit(self)
    self.timer:register(FAST_MS, SECOND_MS, -1, function()
        self.functor:run(self)
    end)
end

function TcpClient:on_quit()
    self.timer:unregister()
    self:close()
end

function TcpClient:check_alive()
    if self.alive then
        local data = { serial = self.serial, time = quanta.now_ms }
        local ok, res = self:call("NID_HEARTBEAT_REQ", data)
        if ok then
            self.serial = res.serial + 1
            self.diff_time = quanta.now_ms - res.time
        end
        return
    end
    self:connect()
end

function TcpClient:dispatch_wait(cmd_id, body)
    --等待协议处理
    local wait_session_id = self.wait_list[cmd_id]
    if wait_session_id then
        self.wait_list[cmd_id] = nil
        thread_mgr:response(wait_session_id, true, body)
    end
end

function TcpClient:dispatch_pb_message(socket, message, cmd_id, session_id)
    if session_id == 0 then
        -- 事件分发
        event_mgr:notify_pb_message(cmd_id, socket, message, message.request)
    else
        --异步回调
        thread_mgr:response(session_id, true, message.request)
    end
end

function TcpClient:dispatch_message(socket, message, cmd_id, session_id, flag)
    -- 事件统计
    event_mgr:notify_trigger("on_recv_tcp_message", message)
    -- 错误处理
    if flag == FLAG_UNREACH or flag == FLAG_BAD then
        log_err("[TcpClient][dispatch_message] cmd_id {} is unreachable in router!", cmd_id)
        if session_id > 0 then
            local code = flag == FLAG_UNREACH and UNREACHABLE or PARAM_ERROR
            thread_mgr:response(session_id, false, code, "target is unreachable!")
        end
        return
    end
    -- 事件分发
    self:dispatch_pb_message(socket, message, cmd_id, session_id)
    self:dispatch_wait(cmd_id, message.request)
end

-- 发起连接
function TcpClient:connect()
    if self.socket then
        return true
    end
    local socket, cerr = socket_mgr.connect(self.ip, self.port, CONNECT_TIMEOUT, PROTO_PB)
    if not socket then
        log_err("[TcpClient][connect] failed to connect: {}:{} err={}", self.ip, self.port, cerr)
        return false, cerr
    end
    --设置阻塞id
    local block_id = lnext_id()
    -- 调用成功，开始安装回调函数
    socket.set_codec(self.codec)
    socket.on_connect = function(res)
        local success = (res == "ok")
        self.alive = success
        if not success then
            self:close()
        end
        thread_mgr:response(block_id, success, res)
    end
    socket.call_client = function(cmd_id, flag, type, session_id, target_id, body)
        if not self.alive then
            log_err("[TcpClient][call_client] session lost! cmd_id:{}-({})", cmd_id, body)
            return false
        end
        local send_len = socket.call_pb(session_id, cmd_id, flag, type, target_id, body)
        if send_len <= 0 then
            log_err("[TcpClient][call_client] call_pb failed! code:{}", send_len)
            return false
        end
        event_mgr:notify_trigger("on_send_tcp_message", cmd_id, body, send_len)
        return true
    end
    socket.on_call_pb = function(recv_len, session_id, target_id, cmd_id, flag, body, err)
        if body then
            local message = Message(socket, session_id, recv_len, body, cmd_id, flag, target_id)
            thread_mgr:fork(self.dispatch_message, nil, self, socket, message, cmd_id, session_id, flag)
            return
        end
        log_warn("[TcpClient][on_call_pb] pb cmd_id({}) decode field: {}!", cmd_id, err and err or "pb not define")
    end
    socket.on_error = function(token, err)
        thread_mgr:fork(self.on_socket_error, nil, self, token, err)
    end
    self.socket = socket
    local ok, res = thread_mgr:yield(block_id, "connect", CONNECT_TIMEOUT)
    if not ok then
        self:close()
        return ok, res
    end
    return self:on_socket_connected(socket)
end

function TcpClient:on_socket_connected()
    self.alive = true
    self.timer:change_period(SECOND_5_MS)
    event_mgr:notify_trigger("on_tcp_connected")
    return true
end

function TcpClient:get_token()
    return self.socket and self.socket.token
end

-- 主动关闭连接
function TcpClient:close()
    self.timer:unregister()
    if self.socket then
        self.socket.close()
        self.alive = false
        self.socket = nil
    end
end

function TcpClient:output(cmd_id, data, type, session_id, flag, target_id)
    local ok = self.socket.call_client(cmd_id, flag, type, session_id, target_id, data)
    if not ok then
        return false
    end
    if not session_id or session_id <= 0 then
        return true
    end
    return thread_mgr:yield(session_id, cmd_id, RPC_CALL_TIMEOUT)
end

-- 发送数据
function TcpClient:send(cmd_id, data, type)
    return self:output(cmd_id, data, type or RELAY_SELF, 0, FLAG_REQ, 0)
end

-- 发起远程命令
function TcpClient:call(cmd_id, data, type)
    local session_id = lnext_id() & 0xffff
    return self:output(cmd_id, data, type or RELAY_SELF, session_id, FLAG_REQ, 0)
end

-- 等待NTF命令或者非RPC命令
function TcpClient:wait(cmd_id, time)
    local session_id = lnext_id()
    self.wait_list[cmd_id] = session_id
    return thread_mgr:yield(session_id, cmd_id, time)
end

-- 连接关闭回调
function TcpClient:on_socket_error(token, err)
    if self.socket then
        self.socket = nil
        self.alive = false
        self.wait_list = {}
    end
end

return TcpClient
