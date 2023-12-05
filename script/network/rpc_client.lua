-- rpc_client.lua

local tunpack           = table.unpack
local log_err           = logger.err
local qdefer            = quanta.defer
local qxpcall           = quanta.xpcall
local hash_code         = codec.hash_code

local event_mgr         = quanta.get("event_mgr")
local timer_mgr         = quanta.get("timer_mgr")
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
prop:reader("alive", false)
prop:reader("socket", nil)
prop:accessor("holder", nil)    --持有者

function RpcClient:__init(holder, ip, port, id)
    self.ip = ip
    self.port = port
    self.holder = holder
    self.id = id or 0
    self.timer_id = timer_mgr:loop(SECOND_MS, function()
        self:check_heartbeat()
    end)
end

function RpcClient:check_heartbeat()
    if not self.holder then
        return
    end
    --处理连接
    if self.alive then
        --发送心跳
        self:send("rpc_heartbeat")
        timer_mgr:set_period(self.timer_id, RPC_TIMEOUT)
    else
        self:connect()
        timer_mgr:set_period(self.timer_id, SECOND_MS)
    end
end

function RpcClient:register()
    self:call("rpc_register", quanta.node_info)
end

--调用rpc后续处理
function RpcClient:on_call_router(rpc, token, send_len)
    if send_len > 0 then
        --proxy_agent:statistics("on_rpc_send", rpc, send_len)
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
    local token = socket.token
    socket.on_call = function(recv_len, session_id, rpc_flag, ...)
        qxpcall(self.on_socket_rpc, "on_socket_rpc: {}", self, socket, session_id, rpc_flag, recv_len, ...)
    end
    socket.call_rpc = function(rpc, session_id, rpc_flag, ...)
        local send_len = socket.call(session_id, rpc_flag, quanta.id, rpc, ...)
        return self:on_call_router(rpc, token, send_len)
    end
    socket.transfer = function(rpc, session_id, target_id, service_id, ...)
        local send_len = socket.forward_transfer(session_id, target_id, service_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, token, send_len)
    end
    socket.call_target = function(rpc, session_id, target, ...)
        local send_len = socket.forward_target(session_id, FLAG_REQ, target, quanta.id, rpc, ...)
        return self:on_call_router(rpc, token, send_len)
    end
    socket.callback_target = function(rpc, session_id, target, ...)
        if target == 0 then
            local send_len = socket.call(session_id, FLAG_RES, quanta.id, rpc, ...)
            return self:on_call_router(rpc, token, send_len)
        else
            local send_len = socket.forward_target(session_id, FLAG_RES, target, quanta.id, rpc, ...)
            return self:on_call_router(rpc, token, send_len)
        end
    end
    socket.call_hash = function(rpc, session_id, service_id, hash_key, ...)
        local hash_value = hash_code(hash_key, 0xffff)
        local send_len = socket.forward_hash(session_id, FLAG_REQ, service_id, hash_value, quanta.id, rpc, ...)
        return self:on_call_router(rpc, token, send_len)
    end
    socket.call_master = function(rpc, session_id, service_id, ...)
        local send_len = socket.forward_master(session_id, FLAG_REQ, service_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, token, send_len)
    end
    socket.call_broadcast = function(rpc, session_id, service_id, ...)
        local send_len = socket.forward_broadcast(session_id, FLAG_REQ, service_id, quanta.id, rpc, ...)
        return self:on_call_router(rpc, token, send_len)
    end
    socket.on_error = function(stoken, err)
        self:on_socket_error(stoken, err)
    end
    socket.on_connect = function(res)
        if res == "ok" then
            qxpcall(self.on_socket_connect, "on_socket_connect: {}", self, socket, res)
        else
            self:on_socket_error(token, res)
        end
    end
    self.socket = socket
end

-- 主动关闭连接
function RpcClient:close()
    log_err("[RpcClient][close] socket {}:{}!", self.ip, self.port)
    if self.socket then
        self.socket.close()
        self.alive = false
        self.socket = nil
    end
end

--rpc事件
function RpcClient:on_socket_rpc(socket, session_id, rpc_flag, recv_len, source, rpc, ...)
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
            event_mgr:execute_hook(rpc, hook, ...)
            local rpc_datas = event_mgr:notify_listener(rpc, ...)
            if session_id > 0 then
                socket.callback_target(rpc, session_id, source, tunpack(rpc_datas))
            end
        end
        thread_mgr:fork(dispatch_rpc_message, ...)
        return
    end
    thread_mgr:response(session_id, ...)
end

--错误处理
function RpcClient:on_socket_error(token, err)
    thread_mgr:fork(function()
        log_err("[RpcClient][on_socket_error] socket {}:{} {}!", self.ip, self.port, err)
        self.socket = nil
        self.alive = false
        if self.holder then
            self.holder:on_socket_error(self, token, err)
            event_mgr:fire_second(function()
                self:check_heartbeat()
            end)
        end
    end)
end

--连接成功
function RpcClient:on_socket_connect(socket)
    --log_info("[RpcClient][on_socket_connect] connect to {}:{} success!", self.ip, self.port)
    thread_mgr:fork(function()
        self.alive = true
        self.holder:on_socket_connect(self)
    end)
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
        local session_id = thread_mgr:build_session_id()
        if self.socket.call_rpc(rpc, session_id, FLAG_REQ, ...) then
            return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
        end
    end
    return false, "socket not connected"
end

return RpcClient
