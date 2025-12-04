--rpc_server.lua

local pairs             = pairs
local tunpack           = table.unpack
local signalquit        = signal.quit
local log_err           = logger.err
local log_warn          = logger.warn
local log_info          = logger.info
local qdefer            = quanta.defer
local qxpcall           = quanta.xpcall
local lnext_id          = luakit.next_id
local hash_code         = codec.hash_code
local derive_port       = luabus.derive_port
local resume_trace      = quanta.resume_trace
local extract_trace     = quanta.extract_trace

local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local socket_mgr        = quanta.get("socket_mgr")

local FLAG_REQ          = quanta.enum("FlagMask", "REQ")
local FLAG_RES          = quanta.enum("FlagMask", "RES")
local SUCCESS           = quanta.enum("KernCode", "SUCCESS")
local RPCLINK_TIMEOUT   = quanta.enum("NetwkTime", "RPCLINK_TIMEOUT")
local RPC_CALL_TIMEOUT  = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local SERVICE_MAX       = 255

local RpcServer = singleton()

local prop = property(RpcServer)
prop:reader("ip", "")           --监听ip
prop:reader("port", 0)          --监听端口
prop:reader("clients", {})
prop:reader("listener", nil)
prop:reader("holder", nil)      --持有者

--induce：根据 order 推导port
function RpcServer:__init(holder, ip, port, induce)
    if not ip or not port then
        log_err("[RpcServer][setup] ip:{} or port:{} is nil", ip, port)
        signalquit()
        return
    end
    local induce_port = induce and (port + quanta.order - 1) or port
    local real_port = derive_port(induce_port, ip)
    local listener = socket_mgr.listen(ip, real_port)
    if not listener then
        log_err("[RpcServer][setup] now listen {}:{} failed", ip, real_port)
        signalquit()
        return
    end
    listener.on_accept = function(client)
        qxpcall(self.on_socket_accept, "on_socket_accept: {}", self, client)
    end
    self.holder = holder
    self.listener = listener
    self.ip, self.port = ip, real_port
    log_info("[RpcServer][setup] now listen {}:{} success!", ip, real_port)
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
function RpcServer:on_socket_rpc(client, session_id, rpc_flag, trace_id, span_id, source, rpc, ...)
    if client.id or rpc == "rpc_register" then
        if session_id == 0 or rpc_flag == FLAG_REQ then
            local function dispatch_rpc_message(...)
                local hook<close> = qdefer()
                event_mgr:execute_hook("on_rpc_recv", hook, rpc, ...)
                local rpc_datas = event_mgr:notify_listener(rpc, client, ...)
                if session_id > 0 then
                    client.call_rpc(rpc, session_id, FLAG_RES, tunpack(rpc_datas))
                end
            end
            thread_mgr:fork(dispatch_rpc_message, resume_trace(trace_id, span_id), ...)
            return
        end
        thread_mgr:response(session_id, ...)
    end
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

--accept事件
function RpcServer:on_socket_accept(client)
    -- 设置超时(心跳)
    client.set_timeout(RPCLINK_TIMEOUT)
    -- 添加会话
    local token = client.token
    self.clients[token] = client
    -- 绑定call/回调
    client.call_rpc = function(rpc, session_id, rpc_flag, ...)
        local send_len = client.call(session_id, rpc_flag, 0, 0, 0, rpc, ...)
        if send_len < 0 then
            log_err("[RpcServer][call_rpc] call failed! code:{}", send_len)
            return false
        end
        return true, SUCCESS
    end
    client.on_call = function(recv_len, session_id, rpc_flag, ...)
        qxpcall(self.on_socket_rpc, "on_socket_rpc: {}", self, client, session_id, rpc_flag, ...)
    end
    client.on_transfer = function(recv_len, session_id, service_id, target_id, trace_id, span_id, slice)
        local function dispatch_rpc_message()
            if service_id < SERVICE_MAX then
                event_mgr:notify_listener("on_transfer_rpc", client, session_id, service_id, slice)
                return
            end
            event_mgr:notify_listener("on_broadcast_rpc", client, target_id, slice)
        end
        thread_mgr:fork(dispatch_rpc_message, resume_trace(trace_id, span_id))
    end
    client.on_error = function(ctoken, err)
        thread_mgr:fork(function()
            self:on_socket_error(ctoken, err)
        end)
    end
    --通知收到新client
    self.holder:on_client_accept(client)
end

--直接调用路由hash
function RpcServer:transfer_call(session_id, target_id, slice)
    local trace_id, span_id = extract_trace()
    return self.listener.transfer_call(session_id, target_id, trace_id, span_id, slice)
end

--直接调用路由hash
function RpcServer:transfer_hash(session_id, service_id, hash_key, rpc, ...)
    local trace_id, span_id = extract_trace()
    local hash_value = hash_code(hash_key, 0xffff)
    local send_len = self.listener.transfer_hash(session_id, service_id, hash_value, trace_id, span_id, 0, rpc, ...)
    if send_len > 0 then
        if session_id > 0 then
            return thread_mgr:yield(session_id, rpc, RPC_CALL_TIMEOUT)
        end
        return true
    end
    return false, "rpc server send failed"
end

--call接口
function RpcServer:wait_call(client, session_id, rpc, ...)
    if client.call_rpc(rpc, 0, FLAG_REQ, ...) then
        return thread_mgr:yield(session_id, rpc, RPC_CALL_TIMEOUT)
    end
    return false, "rpc server send failed"
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

--回调
function RpcServer:callback(client, session_id, ...)
    client.call_rpc("callback", session_id, FLAG_RES, ...)
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
function RpcServer:rpc_heartbeat(client, node)
    --回复心跳
    self:send(client, "on_heartbeat", quanta.id)
end

function RpcServer:rpc_register(client, node)
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
