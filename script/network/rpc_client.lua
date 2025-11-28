-- rpc_client.lua

local tunpack           = table.unpack
local log_err           = logger.err
local log_info          = logger.info
local qdefer            = quanta.defer
local qxpcall           = quanta.xpcall
local lnext_id          = luakit.next_id
local hash_code         = codec.hash_code
local make_timer        = quanta.make_timer
local resume_trace      = quanta.resume_trace
local extract_trace     = quanta.extract_trace

local event_mgr         = quanta.get("event_mgr")
local socket_mgr        = quanta.get("socket_mgr")
local thread_mgr        = quanta.get("thread_mgr")

local FLAG_REQ          = quanta.enum("FlagMask", "REQ")
local FLAG_RES          = quanta.enum("FlagMask", "RES")
local SUCCESS           = quanta.enum("KernCode", "SUCCESS")

local SECOND_MS         = quanta.enum("PeriodTime", "SECOND_MS")
local RPC_TIMEOUT       = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")
local CONNECT_TIMEOUT   = quanta.enum("NetwkTime", "CONNECT_TIMEOUT")

local RpcClient = class()
local prop = property(RpcClient)
prop:reader("id", 0)
prop:reader("ip", nil)
prop:reader("port", nil)
prop:reader("timer", nil)
prop:reader("alive", false)
prop:reader("socket", nil)
prop:accessor("holder", nil)    --持有者

function RpcClient:__init(holder, ip, port, id)
    self.ip = ip
    self.port = port
    self.id = id or 0
    self.holder = holder
    self.timer = make_timer()
    self.timer:loop(SECOND_MS, function()
        self:heartbeat()
    end)
end

function RpcClient:heartbeat()
    if not self.holder then
        return
    end
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

function RpcClient:relocation(holder, host, port)
    self.holder = holder
    self.port = port
    self.ip = host
end

--调用rpc后续处理
function RpcClient:on_call_router(rpc, token, send_len)
    if send_len > 0 then
        return true, send_len
    end
    log_err("[RpcClient][on_call_router] rpc {} call failed! code:{}", rpc, send_len)
    return false
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
    socket.on_call = function(recv_len, session_id, ...)
        qxpcall(self.on_socket_rpc, "on_socket_rpc: {}", self, socket, session_id, ...)
    end
    socket.call_rpc = function(rpc, session_id, rpc_flag, ...)
        local trace_id, span_id = extract_trace()
        local send_len = socket.call(session_id, rpc_flag, trace_id, span_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, token, send_len)
    end
    socket.transfer = function(rpc, session_id, target_id, service_id, ...)
        local trace_id, span_id = extract_trace()
        local send_len = socket.forward_transfer(session_id, FLAG_REQ, target_id, service_id, trace_id, span_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, token, send_len)
    end
    socket.call_target = function(rpc, session_id, target, ...)
        local trace_id, span_id = extract_trace()
        local send_len = socket.forward_target(session_id, FLAG_REQ, target, trace_id, span_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, token, send_len)
    end
    socket.callback_target = function(rpc, session_id, target, ...)
        if target == 0 then
            local send_len = socket.call(session_id, FLAG_RES, 0, 0, quanta.id, rpc, ...)
            return self:on_call_router(rpc, token, send_len)
        else
            local send_len = socket.forward_target(session_id, FLAG_RES, target, 0, 0, quanta.id, rpc, ...)
            return self:on_call_router(rpc, token, send_len)
        end
    end
    socket.call_hash = function(rpc, session_id, service_id, hash_key, ...)
        local trace_id, span_id = extract_trace()
        local hash_value = hash_code(hash_key, 0xffff)
        local send_len = socket.forward_hash(session_id, FLAG_REQ, service_id, hash_value, trace_id, span_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, token, send_len)
    end
    socket.call_master = function(rpc, session_id, service_id, ...)
        local trace_id, span_id = extract_trace()
        local send_len = socket.forward_master(session_id, FLAG_REQ, service_id, trace_id, span_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, token, send_len)
    end
    socket.call_broadcast = function(rpc, session_id, service_id, ...)
        local trace_id, span_id = extract_trace()
        local send_len = socket.forward_broadcast(session_id, FLAG_REQ, service_id, trace_id, span_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, token, send_len)
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

--rpc事件
function RpcClient:on_socket_rpc(socket, session_id, rpc_flag, trace_id, span_id, source, rpc, ...)
    if rpc == "on_heartbeat" then
        return
    end
    if not rpc then
        log_err("[RpcClient][on_socket_rpc] rpc is nil, args :{}!", { ... })
        return
    end
    if session_id == 0 or rpc_flag == FLAG_REQ then
        local function dispatch_rpc_message(...)
            local hook<close> = qdefer()
            event_mgr:execute_hook("on_rpc_recv", hook, rpc, ...)
            local rpc_datas = event_mgr:notify_listener(rpc, ...)
            if session_id > 0 then
                socket.callback_target(rpc, session_id, source, tunpack(rpc_datas))
            end
        end
        thread_mgr:fork(dispatch_rpc_message, resume_trace(trace_id, span_id), ...)
        return
    end
    thread_mgr:response(session_id, ...)
end

--错误处理
function RpcClient:on_socket_error(token, err)
    log_err("[RpcClient][on_socket_error] socket {}:{} {}!", self.ip, self.port, err)
    self.timer:change_period(SECOND_MS)
    if self.holder then
        self.holder:on_socket_error(self, token, err)
    end
    self.alive = false
    self.socket = nil
end

--连接成功
function RpcClient:on_socket_connect()
    --log_info("[RpcClient][on_socket_connect] connect to {}:{} success!", self.ip, self.port)
    self.alive = true
    self.holder:on_socket_connect(self)
    self.timer:change_period(RPC_TIMEOUT)
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
function RpcClient:forward_transfer(target_id, session_id, service_id, rpc, ...)
    if self.alive then
        if self.socket.transfer(rpc, session_id, target_id, service_id, ...) then
            if session_id > 0 then
                return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
            end
        end
        return true
    end
    return false, "socket not connected"
end

--回调
function RpcClient:callback(session_id, ...)
    if self.alive then
        self.socket.call_rpc("callback", session_id, FLAG_RES, ...)
    end
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
