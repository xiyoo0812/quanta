-- rpc_client.lua

local log_err           = logger.err
local log_info          = logger.info
local log_fatal         = logger.fatal
local lnext_id          = luakit.next_id
local hash_code         = codec.hash_code
local make_timer        = quanta.make_timer
local make_functer      = quanta.make_functer
local resume_trace      = quanta.resume_trace
local extract_trace     = quanta.extract_trace

local FLAG_REQ          = luabus.proto_flag.REQ
local FLAG_UNREACH      = luabus.proto_flag.UNREACH

local event_mgr         = quanta.get("event_mgr")
local socket_mgr        = quanta.get("socket_mgr")
local thread_mgr        = quanta.get("thread_mgr")

local SUCCESS           = quanta.enum("KernCode", "SUCCESS")
local UNREACHABLE       = quanta.enum("KernCode", "UNREACHABLE")

local FAST_MS           = quanta.enum("PeriodTime", "FAST_MS")
local SECOND_MS         = quanta.enum("PeriodTime", "SECOND_MS")
local RPC_TIMEOUT       = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")
local CONNECT_TIMEOUT   = quanta.enum("NetwkTime", "CONNECT_TIMEOUT")
local HEARTBEAT_TIME    = quanta.enum("NetwkTime", "HEARTBEAT_TIME")

local Message           = import("feature/message_rpc.lua")

local RpcClient = class()
local prop = property(RpcClient)
prop:reader("id", 0)
prop:reader("ip", nil)
prop:reader("port", nil)
prop:reader("timer", nil)
prop:reader("alive", false)
prop:reader("socket", nil)
prop:reader("functor", nil)
prop:accessor("holder", nil)    --持有者

function RpcClient:__init(holder, ip, port, id)
    self.ip = ip
    self.port = port
    self.id = id or 0
    self.holder = holder
    self.timer = make_timer()
    self.functor = make_functer("check_alive")
    self.timer:register(FAST_MS, SECOND_MS, -1, function()
        self.functor:call(self)
    end)
end

function RpcClient:check_alive()
    if self.alive then
        --发送心跳
        self:send("rpc_heartbeat")
    else
        --处理连接
        self:connect()
    end
end

function RpcClient:register()
    self:call("rpc_register", quanta.node_info)
end

function RpcClient:relocation(host, port)
    self.ip = host
    self.port = port
    self.timer:register(FAST_MS, SECOND_MS, -1, function()
        self.functor:call(self)
    end)
end

--调用rpc后续处理
function RpcClient:on_call_router(rpc, send_len)
    if send_len > 0 then
        return true, send_len
    end
    log_err("[RpcClient][on_call_router] rpc {} call failed! code:{}", rpc, send_len)
    return false
end

local function relay_rpc_message(router_id, session_id, target_id, service_id, ...)
    event_mgr:notify_listener("on_relay_message", router_id, session_id, target_id, service_id, ...)
end

--rpc事件
function RpcClient:dispatch_rpc_message(socket, recv_len, session_id, flag, source, rpc, ...)
    -- 事件统计
    event_mgr:notify_trigger("on_recv_rpc", rpc, recv_len)
    if rpc == "on_heartbeat" then
        return
    end
    if flag == FLAG_UNREACH then
        log_err("[RpcClient][dispatch_rpc_message] rpc {} is unreachable in router!", rpc)
        if session_id > 0 then
            thread_mgr:response(session_id, false, UNREACHABLE, "target is unreachable!")
        end
        return
    end
    -- 事件分发
    if flag & FLAG_REQ == FLAG_REQ then
        local message<close> = Message(socket, session_id, recv_len, source, rpc)
        local ok, err = pcall(event_mgr.notify_message, event_mgr, rpc, message, ...)
        if not ok then
            log_fatal("[RpcClient][dispatch_rpc_message] rpc {} call failed: {}", rpc, err)
            message:callback(false, "dispatch rpc message field!")
        end
        return
    end
    thread_mgr:response(session_id, ...)
end

--连接服务器
function RpcClient:connect()
    --连接中
    if self.socket then
        return true
    end
    --开始连接
    local socket, cerr = socket_mgr.connect(self.ip, self.port, CONNECT_TIMEOUT)
    if not socket then
        log_err("[RpcClient][connect] failed to connect: {}:{} err={}", self.ip, self.port, cerr)
        return false, cerr
    end
    self.socket = socket
    local token = socket.token
    socket.on_call_rpc = function(recv_len, session_id, flag, trace_id, span_id, ...)
        thread_mgr:fork(self.dispatch_rpc_message, resume_trace(trace_id, span_id), self, socket, recv_len, session_id, flag, ...)
    end
    socket.on_relay_rpc = function(recv_len, session_id, target_id, service_id, trace_id, span_id, ...)
        thread_mgr:fork(relay_rpc_message, resume_trace(trace_id, span_id), self.id, session_id, target_id, service_id, ...)
    end
    socket.call_rpc = function(rpc, session_id, flag, ...)
        local trace_id, span_id = extract_trace()
        local send_len = socket.forward_self(session_id, 0, 0, flag, trace_id, span_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.relay = function(rpc, session_id, target_id, service_id, source, ...)
        local trace_id, span_id = extract_trace()
        local send_len = socket.forward_relay(session_id, target_id, service_id, FLAG_REQ, trace_id, span_id, source, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_target = function(rpc, session_id, target, ...)
        local trace_id, span_id = extract_trace()
        local send_len = socket.forward_target(session_id, target, 0, FLAG_REQ, trace_id, span_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.callback_target = function(rpc, session_id, target, flag, ...)
        local send_len = socket.forward_target(session_id, target, 0, flag, 0, 0, quanta.id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_hash = function(rpc, session_id, service_id, hash_key, ...)
        local trace_id, span_id = extract_trace()
        local hash_val = hash_code(hash_key, 0xffff)
        local send_len = socket.forward_hash(session_id, hash_val, service_id, FLAG_REQ, trace_id, span_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_master = function(rpc, session_id, service_id, ...)
        local trace_id, span_id = extract_trace()
        local send_len = socket.forward_master(session_id, 0, service_id, FLAG_REQ, trace_id, span_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_broadcast = function(rpc, session_id, service_id, ...)
        local trace_id, span_id = extract_trace()
        local send_len = socket.forward_broadcast(session_id, 0, service_id, FLAG_REQ, trace_id, span_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.on_error = function(stoken, err)
        thread_mgr:fork(self.on_socket_error, nil, self, stoken, err)
    end
    socket.on_connect = function(res)
        if res == "ok" then
            thread_mgr:fork(self.on_socket_connect, nil, self)
        else
            thread_mgr:fork(self.on_socket_error, nil, self, token, res)
        end
    end
end

-- 主动关闭连接
function RpcClient:close()
    log_info("[RpcClient][close] socket {}:{}!", self.ip, self.port)
    self.timer:unregister()
    if self.socket then
        self.socket.close()
        self.alive = false
        self.socket = nil
    end
end

--错误处理
function RpcClient:on_socket_error(token, err)
    log_err("[RpcClient][on_socket_error] socket {}:{} {}!", self.ip, self.port, err)
    if self.socket then
        self.alive = false
        self.socket = nil
        self.timer:change_period(SECOND_MS)
        self.holder:on_socket_error(self, token, err)
    end
end

--连接成功
function RpcClient:on_socket_connect()
    --log_info("[RpcClient][on_socket_connect] connect to {}:{} success!", self.ip, self.port)
    self.alive = true
    self.holder:on_socket_connect(self)
    self.timer:change_period(HEARTBEAT_TIME)
end

--转发系列接口
function RpcClient:forward_socket(method, rpc, session_id, ...)
    if self.alive then
        if self.socket[method](rpc, session_id, ...) then
            if session_id > 0 then
                return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
            end
            return true, SUCCESS
        end
        return false, "socket send failed"
    end
    return false, "socket not connected"
end

--转发消息
function RpcClient:relay(target_id, session_id, service_id, source, rpc, ...)
    if self.alive then
        if self.socket.relay(rpc, session_id, target_id, service_id, source, ...) then
            if session_id > 0 then
                return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
            end
        end
        return true
    end
    return false, "socket not connected"
end

--直接发送接口
function RpcClient:send(rpc, ...)
    if self.alive then
        self.socket.call_rpc(rpc, 0, FLAG_REQ, ...)
        return true
    end
    return false, "socket not connected"
end

--直接发送接口
function RpcClient:call(rpc, ...)
    if self.alive then
        local session_id = lnext_id()
        if self.socket.call_rpc(rpc, session_id, FLAG_REQ, ...) then
            return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
        end
    end
    return false, "socket not connected"
end

return RpcClient
