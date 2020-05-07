-- rpc_client.lua
local tunpack       = table.unpack
local log_err       = logger.err
local log_info      = logger.info
local qxpcall       = quanta.xpcall

local socket_mgr    = quanta.socket_mgr
local statis_mgr    = quanta.statis_mgr
local perfeval_mgr  = quanta.perfeval_mgr
local thread_mgr    = quanta.thread_mgr

local RpcType       = enum("RpcType")
local KernCode      = enum("KernCode")
local NetwkTime     = enum("NetwkTime")
local SUCCESS       = KernCode.SUCCESS

local RpcClient = class()
local prop = property(RpcClient)
prop:accessor("ip", nil)
prop:accessor("port", nil)
prop:accessor("alive", false)
prop:accessor("socket", nil)
prop:accessor("rpc_mgr", nil)
function RpcClient:__init(rpc_mgr, ip, port)
    self.rpc_mgr = rpc_mgr
    self.port = port
    self.ip = ip
end

--调用rpc后续处理
function RpcClient:on_call_router(rpc, send_len)
    if send_len > 0 then
        statis_mgr:statis_notify("on_rpc_send", rpc, send_len)
        return true, send_len
    end
    log_err("[RpcClient][call_luabus] rpc %s call failed! code:%s", rpc, send_len)
    return false
end

--检测存活
function RpcClient:check_alive(now)
    if self.alive and now - self.alive_time > NetwkTime.RPC_LINK_TIMEOUT then
        self.alive = false
        self.socket = nil
        return true
    end
end

--连接服务器
function RpcClient:connect()
    --开始连接
    local ip, port = self.ip, self.port
    local socket = socket_mgr.connect(ip, port, NetwkTime.CONNECT_TIMEOUT)
    socket.on_call = function(recv_len, session_id, rpc_type, source, rpc, ...)
        statis_mgr:statis_notify("on_rpc_recv", rpc, recv_len)
        local eval = perfeval_mgr:begin_eval("rpc_doer_" .. rpc)
        qxpcall(self.on_socket_rpc, "on_socket_rpc: %s", self, socket, session_id, rpc_type, source, rpc, ...)
        perfeval_mgr:end_eval(eval)
    end
    socket.call_rpc = function(session_id, rpc_type, rpc, ...)
        local send_len = socket.call(session_id, rpc_type, quanta.id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_target = function(session_id, target, rpc, ...)
        local send_len = socket.forward_target(session_id, RpcType.RPC_REQ, quanta.id, target, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.callback_target = function(session_id, target, rpc, ...)
        local send_len = socket.forward_target(session_id, RpcType.RPC_RES, quanta.id, target, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_hash = function(session_id, service_id, hash_key, rpc, ...)
        local send_len = socket.forward_hash(session_id, RpcType.RPC_REQ, quanta.id, service_id, hash_key, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_master = function(session_id, service_id, rpc, ...)
        local send_len = socket.forward_master(session_id, RpcType.RPC_REQ, quanta.id, service_id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_broadcast = function(session_id, service_id, rpc, ...)
        local send_len = socket.forward_broadcast(session_id, RpcType.RPC_REQ, quanta.id, service_id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.on_error = function(err)
        qxpcall(self.on_socket_error, "on_socket_error: %s", self, socket, err)
    end
    socket.on_connect = function(res)
        if res == "ok" then
            log_info("[RpcClient][connect] connect to %s:%s success!", ip, port)
            qxpcall(self.on_socket_connect, "on_socket_connect: %s", self, socket, res)
        else
            log_err("[RpcClient][connect] connect to %s:%s failed, reason=%s", ip, port, res)
            self:on_socket_error(socket, res)
        end
    end
    self.socket = socket
end

--rpc事件
function RpcClient:on_socket_rpc(socket, session_id, rpc_type, source, rpc, ...)
    socket.alive_time = quanta.now
    if session_id == 0 or rpc_type == RpcType.RPC_REQ then
        local function dispatch_rpc_message(...)
            local rpc_datas = quanta.router_mgr:notify_listener(rpc, ...)
            if session_id > 0 then
                socket.callback_target(session_id, source, rpc, tunpack(rpc_datas))
            end
        end
        thread_mgr:fork(dispatch_rpc_message, ...)
        return
    end
    thread_mgr:response(session_id, ...)
end

--错误处理
function RpcClient:on_socket_error(socket, err)
    self.socket = nil
    self.alive = false
    self.rpc_mgr:on_socket_error(self, err)
end

--连接成功
function RpcClient:on_socket_connect(socket)
    self.alive = true
    socket.alive_time = quanta.now
    self.rpc_mgr:on_socket_connect(self)
end

--转发系列接口
function RpcClient:forward_socket(method, session_id, ...)
    local socket = self.socket
    if socket then
        if socket[method](session_id, ...) then
            if session_id > 0 then
                return thread_mgr:yield(session_id, NetwkTime.RPC_CALL_TIMEOUT)
            end
            return true, SUCCESS
        end
        return false, "socket send failed"
    end
    return false, "socket not connected"
end

--直接发送接口
function RpcClient:send(rpc, ...)
    local socket = self.socket
    if socket then
        socket.call_rpc(0, RpcType.RPC_REQ, rpc, ...)
    end
    return false, "socket not connected"
end

--直接发送接口
function RpcClient:call(rpc, ...)
    local socket = self.socket
    if socket then
        local session_id = thread_mgr:build_session_id()
        if socket.call_rpc(session_id, RpcType.RPC_REQ, rpc, ...) then
            return thread_mgr:yield(session_id, NetwkTime.RPC_CALL_TIMEOUT)
        end
    end
    return false, "socket not connected"
end

return RpcClient
