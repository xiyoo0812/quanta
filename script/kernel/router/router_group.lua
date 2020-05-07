-- router_group.lua
local pairs             = pairs
local ipairs            = ipairs
local mrandom           = math.random
local ssplit            = string_ext.split
local tunpack           = table.unpack
local tinsert           = table.insert
local smake_id          = service.make_id
local sid2nick          = service.id2nick
local sid2name          = service.id2name
local sname2sid         = service.name2sid
local log_err           = logger.err
local log_info          = logger.info
local uhash_code        = utility.hash_code
local qxpcall           = quanta.xpcall

local timer_mgr         = quanta.timer_mgr
local socket_mgr        = quanta.socket_mgr
local statis_mgr        = quanta.statis_mgr
local perfeval_mgr      = quanta.perfeval_mgr
local thread_mgr        = quanta.thread_mgr

local KernCode          = enum("KernelCode")
local SUCCESS           = KernCode.SUCCESS

local RECONNECT_TIME    = 5
local CONNECT_WAIT_TIME = 2000
local SERVICE_TIMEOUT   = 10000
local PERIOD_HEARTBEAT  = 2000  --心跳

local LUA_RPC_TIMEOUT   = 5000
local LUC_RPC_TYPE_REQ  = 0 --lua rpc 请求类型
local LUC_RPC_TYPE_RES  = 1 --lua rpc 响应类型

local RouterGroup = class()
function RouterGroup:__init()
    self.master             = nil
    self.routers            = {}
    self.candidates         = {}
    self.watch_server       = {}
    self.watch_reg_server   = {}
    self.rpc_timeout        = LUA_RPC_TIMEOUT

    self:setup()
end

--初始化
function RouterGroup:setup()
    --心跳定时器
    timer_mgr:loop(PERIOD_HEARTBEAT, function()
        self:call_router_all("heartbeat")
    end)
    --添加帧更新
    quanta.join(self)
end

--添加router
function RouterGroup:add_router(router_conf)
    local service_id = sname2sid("router")
    local router_id = smake_id(service_id, router_conf.index)
    if not self.routers[router_id] then
        local ip, port = tunpack(ssplit(router_conf.addr, ":"))
        self.routers[router_id] = {addr = router_conf.addr, ip=ip, port=port, next_connect_time=0, router_id = router_id }
    end
end

--调用router后续处理
function RouterGroup:on_call_router(rpc, send_len)
    if send_len > 0 then
        statis_mgr:statis_notify("on_rpc_send", rpc, send_len)
        return true, send_len
    end
    log_err("[RouterGroup][call_luabus] rpc %s call failed! code:%s", rpc, send_len)
    return false
end

--连接router
function RouterGroup:connect(node)
    local socket = socket_mgr.connect(node.ip, node.port, CONNECT_WAIT_TIME)
    socket.on_call = function(recv_len, session_id, rpc_type, source, rpc, ...)
        statis_mgr:statis_notify("on_rpc_recv", rpc, recv_len)
        local eval = perfeval_mgr:begin_eval("rpc_doer_" .. rpc)
        qxpcall(self.socket_rpc, "socket_rpc: %s", self, node, session_id, rpc_type, source, rpc, ...)
        perfeval_mgr:end_eval(eval)
    end
    socket.call_lua = function(rpc, ...)
        local send_len = socket.call(0, LUC_RPC_TYPE_REQ, quanta.id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_target = function(session_id, target, rpc, ...)
        local send_len = socket.forward_target(session_id, LUC_RPC_TYPE_REQ, quanta.id, target, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.callback_target = function(session_id, target, rpc, ...)
        local send_len = socket.forward_target(session_id, LUC_RPC_TYPE_RES, quanta.id, target, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_hash = function(session_id, service_id, hash_key, rpc, ...)
        local send_len = socket.forward_hash(session_id, LUC_RPC_TYPE_REQ, quanta.id, service_id, hash_key, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_master = function(session_id, service_id, rpc, ...)
        local send_len = socket.forward_master(session_id, LUC_RPC_TYPE_REQ, quanta.id, service_id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.call_broadcast = function(session_id, service_id, rpc, ...)
        local send_len = socket.forward_broadcast(session_id, LUC_RPC_TYPE_REQ, quanta.id, service_id, rpc, ...)
        return self:on_call_router(rpc, send_len)
    end
    socket.on_error = function(err)
        qxpcall(self.on_socket_error, "on_socket_error: %s", self, node, err)
    end
    socket.on_connect = function(res)
        qxpcall(self.on_socket_connect, "on_socket_connect: %s", self, socket, node, res)
    end
    node.socket = socket
end

--rpc事件
function RouterGroup:socket_rpc(node, session_id, rpc_type, source, rpc, ...)
    node.alive_time = quanta.now
    if session_id == 0 or rpc_type == LUC_RPC_TYPE_REQ then
        local function dispatch_rpc_message(...)
            local rpc_datas = quanta.router_mgr:notify_listener(rpc, ...)
            if session_id > 0 then
                self:send_response(session_id, node, source, rpc, tunpack(rpc_datas))
            end
        end
        thread_mgr:fork(dispatch_rpc_message, ...)
        return
    end
    thread_mgr:response(session_id, ...)
end

--错误处理
function RouterGroup:on_socket_error(node, err)
    node.socket = nil
    if node.alive then
        log_err("router lost %s:%s, err=%s", node.ip, node.port, err)
        node.alive = false
        self:switch_master()
    else
        log_err("router connected %s:%s failed, err=%s", node.ip, node.port, err)
    end
end

--连接成功
function RouterGroup:on_socket_connect(socket, node, res)
    if res ~= "ok" then
        node.socket = nil
        log_err("failed to connect router %s:%s, reason=%s", node.ip, node.port, res)
        return
    end
    node.alive = true
    node.alive_time = quanta.now
    --switch master
    self:switch_master()
    --server register
    socket.call_lua("register", quanta.id)

    quanta.router_mgr:notify_trigger("connect_success_ntf")
    log_info("[RouterGroup][on_socket_connect] router %s:%s success!", node.ip, node.port)
end

--切换主router
function RouterGroup:switch_master()
    self.candidates = {}
    for _, node in pairs(self.routers) do
        if node.alive then
            tinsert(self.candidates, node)
        end
    end
    local node = self:random_router()
    if node then
        self.master = node
        log_info("switch router addr: %s", node.addr)
    end
end

--更新
function RouterGroup:update()
    for _, node in pairs(self.routers) do
        if node.alive and quanta.now > node.alive_time + SERVICE_TIMEOUT then
            log_info("router timeout: %s:%s", node.ip, node.port)
            node.alive = false
            node.socket = nil
            self:switch_master()
        end
        if node.socket == nil then
            if quanta.now > node.next_connect_time then
                node.next_connect_time = quanta.now + RECONNECT_TIME
                self:connect(node)
            end
        end
    end
end

function RouterGroup:set_rpc_timeout(msto)
    self.rpc_timeout = msto
end

function RouterGroup:get_rpc_timeout()
    local rpc_timeout = self.rpc_timeout
    self.rpc_timeout = LUA_RPC_TIMEOUT
    return rpc_timeout
end

function RouterGroup:forward_router(method, node, session_id, ...)
    local socket = node and node.socket
    if socket then
        if socket[method](session_id, ...) then
            if session_id > 0 then
                return thread_mgr:yield(session_id, self:get_rpc_timeout())
            end
            return true, SUCCESS
        end
        return false, "router send failed"
    end
    return false, "router not connected"
end

function RouterGroup:forward_broadcast(service_id, rpc, ...)
    return self:forward_router("call_broadcast", self.master, 0, service_id, rpc, ...)
end

--发送给router all
function RouterGroup:call_router_all(rpc, ...)
    for _, node in pairs(self.routers) do
        if node.socket then
            node.socket.call_lua(rpc, ...)
        end
    end
end

--发送给指定目标
function RouterGroup:call_target(target, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    local hash_node = self:hash_router(target)
    return self:forward_router("call_target", hash_node, session_id, target, rpc, ...)
end

--发送给指定目标
function RouterGroup:send_target(target, rpc, ...)
    local hash_node = self:hash_router(target)
    return self:forward_router("call_target", hash_node, 0, target, rpc, ...)
end

--发送回执给指定目标
function RouterGroup:send_response(session_id, node, target, rpc, ...)
    local socket = node and node.socket
    if socket then
        return socket.callback_target(session_id, target, rpc, ...)
    end
    return false, "router not connected"
end

--查找指定router
function RouterGroup:get_router(router_id)
    return self.routers[router_id]
end

--查找随机router
function RouterGroup:random_router()
    local count = #self.candidates
    if count > 0 then
        return self.candidates[mrandom(count)]
    end
end

--查找hash router
function RouterGroup:hash_router(hash_key)
    local count = #self.candidates
    if count > 0 then
        local hash_code = uhash_code(hash_key)
        return self.candidates[(hash_code % count) + 1]
    end
end

function RouterGroup:random_call(target, rpc, ...)
    local node = self:random_router()
    local session_id = thread_mgr:build_session_id()
    return self:forward_router("call_target", node, session_id, target, rpc, ...)
end

function RouterGroup:random_send(target, rpc, ...)
    local node = self:random_router()
    return self:forward_router("call_target", node, 0, target, rpc, ...)
end

function RouterGroup:router_call(router_id, target, rpc, ...)
    local node = self:get_router(router_id)
    local session_id = thread_mgr:build_session_id()
    return self:forward_router("call_target", node, session_id, target, rpc, ...)
end

function RouterGroup:router_send(router_id, target, rpc, ...)
    local node = self:get_router(router_id)
    return self:forward_router("call_target", node, 0, target, rpc, ...)
end

--发送给指定service的hash
function RouterGroup:call_hash(service_id, hash_key, rpc, ...)
    local hash_node = self:hash_router(hash_key)
    local session_id = thread_mgr:build_session_id()
    return self:forward_router("call_hash", hash_node, session_id, service_id, hash_key, rpc, ...)
end

--发送给指定service的hash
function RouterGroup:send_hash(service_id, hash_key, rpc, ...)
    local hash_node = self:hash_router(hash_key)
    return self:forward_router("call_hash", hash_node, 0, service_id, hash_key, rpc, ...)
end

--发送给指定service的master
function RouterGroup:call_master(service_id, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    return self:forward_router("call_master", self.master, session_id, service_id, rpc, ...)
end

--发送给指定service的master
function RouterGroup:send_master(service_id, rpc, ...)
    return self:forward_router("call_master", self.master, 0, service_id, rpc, ...)
end

--监听服务断开
function RouterGroup:watch_service_close(listener, service_id)
    if not self.watch_server[service_id] then
        self.watch_server[service_id] = {}
    end
    self.watch_server[service_id][listener] = true
end

--监听服务注册
function RouterGroup:watch_service_register(listener, service_id)
    if not self.watch_reg_server[service_id] then
        self.watch_reg_server[service_id] = {}
    end
    self.watch_reg_server[service_id][listener] = true
end

--rpc
-------------------------------------------------------------------
--服务器关闭
function RouterGroup:service_close(id)
    log_info("RouterGroup:service_close->name:%s", sid2nick(id))
    local ser_name = sid2name(id)
    local listener_set = self.watch_server[ser_name]
    for listener in pairs(listener_set or {}) do
        if listener and type(listener.on_service_close) == "function" then
            listener:on_service_close(id, ser_name)
        end
    end
end

--服务器注册
function RouterGroup:service_register(id, ser_name, router_id)
    local listener_set = self.watch_reg_server[ser_name]
    for listener in pairs(listener_set or {}) do
        if listener and type(listener.on_service_register) == "function" then
            listener:on_service_register(id, ser_name, router_id)
        end
    end
end

return RouterGroup
