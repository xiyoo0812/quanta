--rpc_server.lua
local next          = next
local pairs         = pairs
local tunpack       = table.unpack
local log_err       = logger.err
local log_info      = logger.info
local qxpcall       = quanta.xpcall

local FlagMask      = enum("FlagMask")
local KernCode      = enum("KernCode")
local NetwkTime     = enum("NetwkTime")
local SUCCESS       = KernCode.SUCCESS

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local socket_mgr    = quanta.get("socket_mgr")
local statis_mgr    = quanta.get("statis_mgr")
local perfeval_mgr  = quanta.get("perfeval_mgr")

local RpcServer = singleton()

local prop = property(RpcServer)
prop:accessor("clients", {})
prop:accessor("listener", nil)
prop:accessor("port", 0)                    --监听端口
prop:accessor("ip", "")                     --监听ip
function RpcServer:__init()
end

--初始化
function RpcServer:setup(ip, port, induce)
    if not ip or not port then
        log_err("[RpcServer][setup] ip:%s or port:%s is nil", ip, port)
        os.exit(1)
    end
    local real_port = induce and (port + quanta.index - 1) or port
    self.listener = socket_mgr.listen(ip, real_port)
    if not self.listener then
        log_err("[RpcServer][setup] now listen %s:%s failed", ip, real_port)
        os.exit(1)
    end
    self.ip, self.port = ip, real_port
    log_info("[RpcServer][setup] now listen %s:%s success!", ip, real_port)
    self.listener.on_accept = function(client)
        qxpcall(self.on_socket_accept, "on_socket_accept: %s", self, client)
    end
    event_mgr:add_listener(self, "rpc_heartbeat")
end

--rpc事件
function RpcServer:on_socket_rpc(client, rpc, session_id, rpc_flag, source, ...)
    client.alive_time = quanta.now
    if session_id == 0 or rpc_flag == FlagMask.REQ then
        local function dispatch_rpc_message(...)
            local eval = perfeval_mgr:begin_eval("rpc." .. rpc)
            local rpc_datas = event_mgr:notify_listener(rpc, client, ...)
            if session_id > 0 then
                client.call_rpc(session_id, FlagMask.RES, rpc, tunpack(rpc_datas))
            end
            perfeval_mgr:end_eval(eval)
        end
        thread_mgr:fork(dispatch_rpc_message, ...)
        return
    end
    thread_mgr:response(session_id, ...)
end

--连接关闭
function RpcServer:on_socket_close(client, err)
    local client_token = client.token
    --log_err("[RpcServer][on_socket_close] %s lost: %s", client.name or client_token, err)
    self.clients[client_token] = nil
    event_mgr:notify_listener("on_socket_close", client, client_token, err)
end

--accept事件
function RpcServer:on_socket_accept(client)
    --log_info("[RpcServer][on_socket_accept] new connection, token=%s", client.token)
    client.set_timeout(NetwkTime.ROUTER_TIMEOUT)
    self.clients[client.token] = client

    client.call_rpc = function(session_id, rpc_flag, rpc, ...)
        local send_len = client.call(session_id, rpc_flag, 0, rpc, ...)
        if send_len < 0 then
            statis_mgr:statis_notify("on_rpc_send", rpc, send_len)
            log_err("[RpcServer][call_rpc] call failed! code:%s", send_len)
            return false
        end
        return true, SUCCESS
    end
    client.on_call = function(recv_len, session_id, rpc_flag, source, rpc, ...)
        statis_mgr:statis_notify("on_rpc_recv", rpc, recv_len)
        qxpcall(self.on_socket_rpc, "on_socket_rpc: %s", self, client, rpc, session_id, rpc_flag, source, ...)
    end
    client.on_error = function(err)
        qxpcall(self.on_socket_close, "on_socket_close: %s", self, client, err)
    end
    --通知收到新client
    event_mgr:notify_listener("on_socket_accept", client)
end

--send接口
function RpcServer:call(client, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    if client.call_rpc(session_id, FlagMask.REQ, rpc, ...) then
        return thread_mgr:yield(session_id, rpc, NetwkTime.RPC_CALL_TIMEOUT)
    end
    return false, "rpc server send failed"
end

--send接口
function RpcServer:send(client, rpc, ...)
    return client.call_rpc(0, FlagMask.REQ, rpc, ...)
end

--boardcast接口
function RpcServer:boardcast(rpc, ...)
    for _, client in pairs(self.clients) do
        client.call_rpc(0, FlagMask.REQ, rpc, ...)
    end
end

--迭代器
function RpcServer:iterator()
    local index = nil
    local clients = self.clients
    local function iter()
        index = next(clients, index)
        if index then
            return index, clients[index]
        end
    end
    return iter
end

--rpc回执
-----------------------------------------------------------------------------
--服务器心跳协议
function RpcServer:rpc_heartbeat(client, qid)
    self:send(client, "on_heartbeat", quanta.id)
end

return RpcServer
