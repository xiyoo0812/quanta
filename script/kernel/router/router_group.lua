-- router_group.lua
local pairs             = pairs
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

local timer_mgr         = quanta.timer_mgr
local thread_mgr        = quanta.thread_mgr

local NetwkTime         = enum("NetwkTime")

local RouterGroup = class()
local prop = property(RouterGroup)
prop:accessor("master", nil)
prop:accessor("routers", {})
prop:accessor("candidates", {})
prop:accessor("watch_server", {})
prop:accessor("watch_reg_server", {})
function RouterGroup:__init()
    self:setup()
end

--初始化
function RouterGroup:setup()
    --心跳定时器
    timer_mgr:loop(NetwkTime.HEARTBEAT_TIME, function()
        self:call_router_all("rpc_heartbeat", quanta.id)
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
        local RpcClient = import("kernel/network/rpc_client.lua")
        self.routers[router_id] = {
            router_id = router_id,
            next_connect_time = 0,
            addr = router_conf.addr,
            client = RpcClient(self, ip, port)
        }
    end
end

--错误处理
function RouterGroup:on_socket_error(client, err)
    log_err("[RouterGroup][on_socket_error] router lost %s:%s, err=%s", client.ip, client.port, err)
end

--连接成功
function RouterGroup:on_socket_connect(client, res)
    log_info("[RouterGroup][on_socket_connect] router %s:%s success!", client.ip, client.port)
    --switch master
    self:switch_master()
    --server register
    client:send("rpc_router_register", quanta.id)
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
        log_info("[RouterGroup][switch_master] switch router addr: %s", node.addr)
    end
end

--更新
function RouterGroup:update()
    local now_tick = quanta.now
    for _, node in pairs(self.routers) do
        local client = node.client
        if not client:get_socket() then
            if now_tick > node.next_connect_time then
                node.next_connect_time = now_tick + NetwkTime.RECONNECT_TIME
                client:connect()
            end
        else
            if client:check_alive(now_tick) then
                log_info("[RouterGroup][update] router timeout: %s:%s", client.ip, client.port)
                if node == self.master then
                    self:switch_master()
                end
            end
        end
    end
end

function RouterGroup:forward_broadcast(service_id, rpc, ...)
    return self.master.client:forward_socket("call_broadcast", 0, service_id, rpc, ...)
end

--发送给router all
function RouterGroup:call_router_all(rpc, ...)
    for _, node in pairs(self.routers) do
        node.client:send(rpc, ...)
    end
end

--发送给指定目标
function RouterGroup:call_target(target, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    local hash_node = self:hash_router(target)
    return hash_node.client:forward_router("call_target", session_id, target, rpc, ...)
end

--发送给指定目标
function RouterGroup:send_target(target, rpc, ...)
    local hash_node = self:hash_router(target)
    return hash_node.client:forward_router("call_target", 0, target, rpc, ...)
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
    return node.client:forward_router("call_target", session_id, target, rpc, ...)
end

function RouterGroup:random_send(target, rpc, ...)
    local node = self:random_router()
    return node.client:forward_router("call_target", 0, target, rpc, ...)
end

function RouterGroup:router_call(router_id, target, rpc, ...)
    local node = self:get_router(router_id)
    local session_id = thread_mgr:build_session_id()
    return node.client:forward_router("call_target", session_id, target, rpc, ...)
end

function RouterGroup:router_send(router_id, target, rpc, ...)
    local node = self:get_router(router_id)
    return node.client:forward_router("call_target", 0, target, rpc, ...)
end

--发送给指定service的hash
function RouterGroup:call_hash(service_id, hash_key, rpc, ...)
    local hash_node = self:hash_router(hash_key)
    local session_id = thread_mgr:build_session_id()
    return hash_node.client:forward_router("call_hash", session_id, service_id, hash_key, rpc, ...)
end

--发送给指定service的hash
function RouterGroup:send_hash(service_id, hash_key, rpc, ...)
    local hash_node = self:hash_router(hash_key)
    return hash_node.client:forward_router("call_hash", 0, service_id, hash_key, rpc, ...)
end

--发送给指定service的master
function RouterGroup:call_master(service_id, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    return self.master.client:forward_router("call_master", session_id, service_id, rpc, ...)
end

--发送给指定service的master
function RouterGroup:send_master(service_id, rpc, ...)
    return self.master.client:forward_router("call_master", 0, service_id, rpc, ...)
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
function RouterGroup:on_service_close(id)
    log_info("RouterGroup:on_service_close->name:%s", sid2nick(id))
    local ser_name = sid2name(id)
    local listener_set = self.watch_server[ser_name]
    for listener in pairs(listener_set or {}) do
        if listener and type(listener.on_service_close) == "function" then
            listener:on_service_close(id, ser_name)
        end
    end
end

--服务器注册
function RouterGroup:on_service_register(id, ser_name, router_id)
    local listener_set = self.watch_reg_server[ser_name]
    for listener in pairs(listener_set or {}) do
        if listener and type(listener.on_service_register) == "function" then
            listener:on_service_register(id, ser_name, router_id)
        end
    end
end

return RouterGroup
