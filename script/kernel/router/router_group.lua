-- router_group.lua
local pairs             = pairs
local ipairs            = ipairs
local mrandom           = math.random
local ssplit            = quanta_extend.split
local tunpack           = table.unpack
local tinsert           = table.insert
local signal_quit       = signal.quit
local sid2name          = service.id2name
local smake_id          = service.make_id
local sget_group        = service.get_group
local services          = service.groups
local log_err           = logger.err
local log_info          = logger.info
local uhash_code        = utility.hash_code
local qxpcall           = quanta.xpcall

local timer_mgr         = quanta.timer_mgr
local socket_mgr        = quanta.socket_mgr
local statis_mgr        = quanta.statis_mgr
local perfeval_mgr      = quanta.perfeval_mgr
local thread_mgr        = quanta.thread_mgr

local errcode           = err.Code
local SUCCESS           = errcode.SUCCESS

local RECONNECT_TIME    = 5
local CONNECT_WAIT_TIME = 2000
local SERVICE_TIMEOUT   = 10000
local PERIOD_HEARTBEAT  = 2000  --心跳

local LUA_RPC_TIMEOUT   = 5000
local LUC_RPC_TYPE_REQ  = 0 --lua rpc 请求类型
local LUC_RPC_TYPE_RES  = 1 --lua rpc 响应类型

local RouterGroup = class()
function RouterGroup:__init(routers_addr)
    self.master             = nil
    self.routers            = {}
    self.candidates         = {}
    self.watch_server       = {}
    self.watch_reg_server   = {}
    self.rpc_timeout        = LUA_RPC_TIMEOUT

    self:setup(routers_addr)
end

--初始化
function RouterGroup:setup(routers_addr)
    self:update_routers(routers_addr)
    --心跳定时器
    timer_mgr:loop(PERIOD_HEARTBEAT, function()
        self:call_router_all("heartbeat")
    end)
end

function RouterGroup:update_routers(routers_addr)
    for _, data in ipairs(routers_addr) do
        local router_id = smake_id(services.router, data.index)
        if not self.routers[router_id] then
            local ip, port = tunpack(ssplit(data.addr, ":"))
            self.routers[router_id] = {addr = data.addr, ip=ip, port=port, next_connect_time=0, router_id = router_id }
        end
    end
end

function RouterGroup:on_call_luabus(rpc, send_len)
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
        return self:on_call_luabus(rpc, send_len)
    end
    socket.call_target = function(session_id, target, rpc, ...)
        local send_len = socket.forward_target(session_id, LUC_RPC_TYPE_REQ, quanta.id, target, rpc, ...)
        return self:on_call_luabus(rpc, send_len)
    end
    socket.callback_target = function(session_id, target, rpc, ...)
        local send_len = socket.forward_target(session_id, LUC_RPC_TYPE_RES, quanta.id, target, rpc, ...)
        return self:on_call_luabus(rpc, send_len)
    end
    socket.call_hash = function(session_id, group, hash_key, rpc, ...)
        local send_len = socket.forward_hash(session_id, LUC_RPC_TYPE_REQ, quanta.id, group, hash_key, rpc, ...)
        return self:on_call_luabus(rpc, send_len)
    end
    socket.call_master = function(session_id, group, rpc, ...)
        local send_len = socket.forward_master(session_id, LUC_RPC_TYPE_REQ, quanta.id, group, rpc, ...)
        return self:on_call_luabus(rpc, send_len)
    end
    socket.call_broadcast = function(session_id, group, rpc, ...)
        local send_len = socket.forward_broadcast(session_id, LUC_RPC_TYPE_REQ, quanta.id, group, rpc, ...)
        return self:on_call_luabus(rpc, send_len)
    end
    socket.on_error = function(err)
        qxpcall(self.socket_on_error, "socket_on_error: %s", self, node, err)
    end
    socket.on_connect = function(res)
        qxpcall(self.socket_on_connect, "socket_on_connect: %s", self, socket, node, res)
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
function RouterGroup:socket_on_error(node, err)
    log_err("router lost %s:%s, err=%s", node.ip, node.port, err)
    node.socket = nil
    node.alive = false
    self:switch_master()
end

--连接成功
function RouterGroup:socket_on_connect(socket, node, res)
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
    log_info("[RouterGroup][socket_on_connect] router %s:%s success!", node.ip, node.port)
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

function RouterGroup:forward_broadcast(group, rpc, ...)
    return self:forward_router("call_broadcast", self.master, 0, group, rpc, ...)
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

--类似于call_target,但是不走当前router,而是随机
--注意,有时序不一致的风险,如果调用此函数,请确保你知道意味着什么
--一般用于分散出口流量,减少单个进程往某个router输出流量过大的风险
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

--发送给指定组的hash
function RouterGroup:call_hash(group, hash_key, rpc, ...)
    local hash_node = self:hash_router(hash_key)
    local session_id = thread_mgr:build_session_id()
    return self:forward_router("call_hash", hash_node, session_id, group, hash_key, rpc, ...)
end

--发送给指定组的hash
function RouterGroup:send_hash(group, hash_key, rpc, ...)
    local hash_node = self:hash_router(hash_key)
    return self:forward_router("call_hash", hash_node, 0, group, hash_key, rpc, ...)
end

--发送给指定组的master
function RouterGroup:call_master(group, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    return self:forward_router("call_master", self.master, session_id, group, rpc, ...)
end

--发送给指定组的master
function RouterGroup:send_master(group, rpc, ...)
    return self:forward_router("call_master", self.master, 0, group, rpc, ...)
end

--监听服务器断开
function RouterGroup:watch_server_close(listener, group)
    if not self.watch_server[group] then
        self.watch_server[group] = {}
    end
    self.watch_server[group][listener] = true
end

--监听服务器注册
function RouterGroup:watch_server_register(listener, group)
    if not self.watch_reg_server[group] then
        self.watch_reg_server[group] = {}
    end
    self.watch_reg_server[group][listener] = true
end

--rpc
-------------------------------------------------------------------
--服务器关闭
function RouterGroup:server_close(id)
    log_info("RouterGroup:server_close->name:%s", sid2name(id))

    local group = sget_group(id)
    local listener_set = self.watch_server[group]
    if not listener_set then return end

    for listener in pairs(listener_set) do
        if listener and type(listener.on_server_close) == "function" then
            listener:on_server_close(id, group)
        end
    end
end

--服务器注册
function RouterGroup:server_register(id, group, router_id)
    local listener_set = self.watch_reg_server[group]
    if not listener_set then return end

    for listener in pairs(listener_set) do
        if listener and type(listener.on_server_register) == "function" then
            listener:on_server_register(id, group, router_id)
        end
    end
end

return RouterGroup
