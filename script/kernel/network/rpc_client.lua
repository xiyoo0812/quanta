-- rpc_client.lua
local tunpack       = table.unpack
local log_err       = logger.err
local qxpcall       = quanta.xpcall

local event_mgr     = quanta.event_mgr
local socket_mgr    = quanta.socket_mgr
local statis_mgr    = quanta.statis_mgr
local perfeval_mgr  = quanta.perfeval_mgr
local thread_mgr    = quanta.thread_mgr

local FlagMask      = enum("FlagMask")
local KernCode      = enum("KernCode")
local NetwkTime     = enum("NetwkTime")
local SUCCESS       = KernCode.SUCCESS

local RpcClient = class()
local prop = property(RpcClient)
prop:accessor("ip", nil)
prop:accessor("port", nil)
prop:accessor("alive", false)
prop:accessor("socket", nil)
prop:accessor("holder", nil)    --持有者
function RpcClient:__init(holder, ip, port)
    self.holder = holder
    self.port = port
    self.ip = ip
end

--调用rpc后续处理
function RpcClient:on_call_router(rpc, send_len)
    if send_len > 0 then
        statis_mgr:statis_notify("on_rpc_send", rpc, send_len)
        return true, send_len
    end
    log_err("[RpcClient][on_call_router] rpc %s call failed! code:%s", rpc, send_len)
    return false
end

--检测存活
function RpcClient:check_lost(now)
    if now - self.socket.alive_time > NetwkTime.ROUTER_TIMEOUT then
        self:close()
        return true
    end
end

--发送心跳
function RpcClient:heartbeat()
    self:send("rpc_heartbeat", quanta.id)
end

--连接服务器
function RpcClient:connect()
    --开始连接
    local socket = socket_mgr.connect(self.ip, self.port, NetwkTime.CONNECT_TIMEOUT)
    socket.on_call = function(recv_len, session_id, rpc_flag, source, rpc, ...)
        statis_mgr:statis_notify("on_rpc_recv", rpc, recv_len)
        qxpcall(self.on_socket_rpc, "on_socket_rpc: %s", self, socket, session_id, rpc_flag, source, rpc, ...)
    end
    socket.call_rpc = function(session_id, rpc_flag, rpc, ...)
        local send_len = socket.call(session_id, rpc_flag, quanta.id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_target = function(session_id, target, rpc, ...)
        local send_len = socket.forward_target(session_id, FlagMask.REQ, quanta.id, target, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.callback_target = function(session_id, target, rpc, ...)
        if target == 0 then
            local send_len = socket.call(session_id, FlagMask.RES, quanta.id, rpc, ...)
            return self:on_call_router(rpc, send_len)
        else
            local send_len = socket.forward_target(session_id, FlagMask.RES, quanta.id, target, rpc, ...)
            return self:on_call_router(rpc, send_len)
        end
    end
    socket.call_hash = function(session_id, service_id, hash_key, rpc, ...)
        local send_len = socket.forward_hash(session_id, FlagMask.REQ, quanta.id, service_id, hash_key, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_master = function(session_id, service_id, rpc, ...)
        local send_len = socket.forward_master(session_id, FlagMask.REQ, quanta.id, service_id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_broadcast = function(session_id, service_id, rpc, ...)
        local send_len = socket.forward_broadcast(session_id, FlagMask.REQ, quanta.id, service_id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.on_error = function(err)
        qxpcall(self.on_socket_error, "on_socket_error: %s", self, socket, err)
    end
    socket.on_connect = function(res)
        if res == "ok" then
            qxpcall(self.on_socket_connect, "on_socket_connect: %s", self, socket, res)
        else
            self:on_socket_error(socket, res)
        end
    end
    self.socket = socket
end

-- 主动关闭连接
function RpcClient:close()
    if self.socket then
        self.socket.close()
        self.alive = false
        self.socket = nil
    end
end

--心跳回复
function RpcClient:on_heartbeat(socket, qid)
end

--rpc事件
function RpcClient:on_socket_rpc(socket, session_id, rpc_flag, source, rpc, ...)
    socket.alive_time = quanta.now
    if rpc == "on_heartbeat" then
        return self:on_heartbeat(...)
    end
    if session_id == 0 or rpc_flag == FlagMask.REQ then
        local function dispatch_rpc_message(...)
            local eval = perfeval_mgr:begin_eval("rpc." .. rpc)
            local rpc_datas = event_mgr:notify_listener(rpc, ...)
            if session_id > 0 then
                socket.callback_target(session_id, source, rpc, tunpack(rpc_datas))
            end
            perfeval_mgr:end_eval(eval)
        end
        thread_mgr:fork(dispatch_rpc_message, ...)
        return
    end
    thread_mgr:response(session_id, ...)
end

--错误处理
function RpcClient:on_socket_error(socket, err)
    --log_err("[RpcClient][on_socket_error] socket %s:%s %s!", self.ip, self.port, err)
    local socket_error = function()
        self.socket = nil
        self.alive = false
        self.holder:on_socket_error(self, err)
    end
    thread_mgr:fork(socket_error)
end

--连接成功
function RpcClient:on_socket_connect(socket)
    --log_info("[RpcClient][on_socket_connect] connect to %s:%s success!", self.ip, self.port)
    local socket_connect = function()
        self.alive = true
        socket.alive_time = quanta.now
        self.holder:on_socket_connect(self)
    end
    thread_mgr:fork(socket_connect)
end

--转发系列接口
function RpcClient:forward_socket(method, session_id, ...)
    if self.alive then
        if self.socket[method](session_id, ...) then
            if session_id > 0 then
                return thread_mgr:yield(session_id, method, NetwkTime.RPC_CALL_TIMEOUT)
            end
            return true, SUCCESS
        end
        return false, "socket send failed"
    end
    return false, "socket not connected"
end

--直接发送接口
function RpcClient:send(rpc, ...)
    if self.alive then
        self.socket.call_rpc(0, FlagMask.REQ, rpc, ...)
    end
    return false, "socket not connected"
end

--直接发送接口
function RpcClient:call(rpc, ...)
    if self.alive then
        local session_id = thread_mgr:build_session_id()
        if self.socket.call_rpc(session_id, FlagMask.REQ, rpc, ...) then
            return thread_mgr:yield(session_id, rpc, NetwkTime.RPC_CALL_TIMEOUT)
        end
    end
    return false, "socket not connected"
end

return RpcClient
