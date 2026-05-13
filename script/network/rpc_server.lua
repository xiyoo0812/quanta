--rpc_server.lua

local pairs             = pairs
local signalquit        = signal.quit
local log_err           = logger.err
local log_warn          = logger.warn
local log_info          = logger.info
local log_fatal         = logger.fatal
local qxpcall           = quanta.xpcall
local lnext_id          = luakit.next_id
local derive_port       = luabus.derive_port
local resume_trace      = quanta.resume_trace

local FLAG_REQ          = luabus.proto_flag.REQ

local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local socket_mgr        = quanta.get("socket_mgr")

local SUCCESS           = quanta.enum("KernCode", "SUCCESS")
local RPCLINK_TIMEOUT   = quanta.enum("NetwkTime", "RPCLINK_TIMEOUT")
local RPC_CALL_TIMEOUT  = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")
local INDUCE            = quanta.enum("PortMode", "INDUCE")
local INCR              = quanta.enum("PortMode", "INCR")

local Message           = import("feature/message_rpc.lua")

local RpcServer = singleton()

local prop = property(RpcServer)
prop:reader("ip", "")           --监听ip
prop:reader("port", 0)          --监听端口
prop:reader("clients", {})
prop:reader("listener", nil)
prop:reader("holder", nil)      --持有者

function RpcServer:__init(holder, ip, port, induce)
    if not ip or not port then
        log_err("[RpcServer][setup] ip:{} or port:{} is nil", ip, port)
        signalquit()
        return
    end
    if induce == INDUCE then
        port = port + quanta.order - 1
    elseif induce == INCR then
        port = derive_port(port + quanta.order - 1, ip)
    end
    local listener = socket_mgr.listen(ip, port)
    if not listener then
        log_err("[RpcServer][setup] now listen {}:{} failed", ip, port)
        signalquit()
        return
    end
    listener.on_accept = function(client)
        qxpcall(self.on_socket_accept, "on_socket_accept: {}", self, client)
    end
    self.holder = holder
    self.listener = listener
    self.ip, self.port = ip, port
    log_info("[RpcServer][setup] now listen {}:{} success!", ip, port)
    event_mgr:add_listener(self, "rpc_heartbeat")
    event_mgr:add_listener(self, "rpc_register")
    --注册退出
    update_mgr:attach_quit(self)
end

function RpcServer:on_quit()
    if self.listener then
        self.listener.close()
        self.listener = nil
        self.codec = nil
        log_info("[RpcServer][on_quit]")
    end
end

--rpc事件
function RpcServer:dispatch_rpc_message(client, recv_len, session_id, flag, source, rpc, ...)
    -- 事件统计
    event_mgr:notify_trigger("on_recv_rpc_message", rpc, recv_len)
    -- 事件分发
    if client.id or rpc == "rpc_register" then
        if flag & FLAG_REQ == FLAG_REQ then
            local message<close> = Message(client, session_id, recv_len, source, rpc)
            local ok, err = pcall(event_mgr.notify_message, event_mgr, rpc, message, ...)
            if not ok then
                log_fatal("[RpcServer][dispatch_rpc_message] rpc {} call failed: {}", rpc, err)
                message:callback(false, "dispatch rpc message field!")
            end
        end
    end
end

--调用rpc后续处理
function RpcServer:on_call_router(rpc, send_len)
    if send_len > 0 then
        event_mgr:notify_trigger("on_send_rpc_message", rpc, send_len)
        return true, SUCCESS
    end
    log_err("[RpcServer][on_call_router] rpc {} call failed! code:{}", rpc, send_len)
    return false
end

--accept事件
function RpcServer:on_socket_accept(client)
    -- 设置超时(心跳)
    client.set_timeout(RPCLINK_TIMEOUT)
    -- 添加会话
    local token = client.token
    self.clients[token] = client
    -- 绑定call/回调
    client.call_rpc = function(rpc, session_id, flag, ...)
        local send_len = client.forward_self(session_id, 0, 0, flag, 0, 0, 0, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    client.callback_target = function(rpc, session_id, target, flag, ...)
        local send_len = client.forward_self(session_id, target, 0, flag, 0, 0, quanta.id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    client.on_call_rpc = function(recv_len, session_id, flag, trace_id, span_id, ...)
        thread_mgr:fork(self.dispatch_rpc_message, resume_trace(trace_id, span_id), self, client, recv_len, session_id, flag, ...)
    end
    client.on_error = function(ctoken, err)
        thread_mgr:fork(self.on_socket_error, nil, self, ctoken, err)
    end
    --通知收到新client
    self.holder:on_client_accept(client)
end

--连接关闭
function RpcServer:on_socket_error(token, err)
    local client = self.clients[token]
    if client then
        self.clients[token] = nil
        if client.id then
            self.holder:on_client_error(client, token, err)
        end
    end
end

--call接口
function RpcServer:call(client, rpc, ...)
    local session_id = lnext_id()
    if client.call_rpc(rpc, session_id, FLAG_REQ, ...) then
        return thread_mgr:yield(session_id, rpc, RPC_CALL_TIMEOUT)
    end
    return false, "rpc server send failed"
end

--send接口
function RpcServer:send(client, rpc, ...)
    return client.call_rpc(rpc, 0, FLAG_REQ, ...)
end

--broadcast接口
function RpcServer:broadcast(rpc, ...)
    for _, client in pairs(self.clients) do
        if client.service then
            client.call_rpc(rpc, 0, FLAG_REQ, ...)
        end
    end
end

--servicecast接口
function RpcServer:servicecast(service_name, rpc, ...)
    for _, client in pairs(self.clients) do
        if client.service and client.service_name == service_name then
            client.call_rpc(rpc, 0, FLAG_REQ, ...)
        end
    end
end

--unservicecast接口
function RpcServer:unservicecast(service_name, rpc, ...)
    for _, client in pairs(self.clients) do
        if client.service and client.service_name ~= service_name then
            client.call_rpc(rpc, 0, FLAG_REQ, ...)
        end
    end
end

--groupecast接口
function RpcServer:groupecast(groups, rpc, ...)
    for token in pairs(groups) do
        local client = self.clients[token]
        if client then
            client.call_rpc(rpc, 0, FLAG_REQ, ...)
        end
    end
end

-- 关闭会话
function RpcServer:close_client(client)
    if client then
        self.clients[client.token] = nil
        client.close()
    end
end

--获取client
function RpcServer:get_client(token)
    return self.clients[token]
end

--获取client
function RpcServer:get_client_by_id(quanta_id)
    for _, client in pairs(self.clients) do
        if client.id == quanta_id then
            return client
        end
    end
end

--rpc回执
-----------------------------------------------------------------------------
--服务器心跳协议
function RpcServer:rpc_heartbeat(message, node)
end

function RpcServer:rpc_register(message, node)
    local client = message.session
    if not client.id then
        -- 检查错误注册
        if node.cluster ~= quanta.cluster then
            log_warn("[RpcServer][rpc_register] illegal client({}-{}-{}) register!", node.name, node.host, node.cluster)
            return
        end
        -- 检查重复注册
        local client_id = node.id
        local eclient = self:get_client_by_id(client_id)
        if eclient then
            eclient.id = nil
            self:send(eclient, "rpc_service_kickout", quanta.id, "service replace")
            log_warn("[RpcServer][rpc_register] client({}-{}) is replace will be kickout!", eclient.name, eclient.host)
            log_warn("[RpcServer][rpc_register] client({}-{}) is online!", node.name, node.host)
        end
        -- 通知注册
        client.id = client_id
        client.name = node.name
        client.service = node.service
        client.service_name = node.service_name
        self.holder:on_client_register(client, node, client_id)
    end
end

return RpcServer
