-- router_group.lua
local pairs             = pairs
local mrandom           = math.random
local ssplit            = string_ext.split
local tunpack           = table.unpack
local tinsert           = table.insert
local smake_id          = service.make_id
local sid2name          = service.id2name
local log_err           = logger.err
local log_info          = logger.info
local uhash_code        = utility.hash_code
local check_success     = utility.check_success

local timer_mgr         = quanta.get("timer_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local update_mgr        = quanta.get("update_mgr")

local NetwkTime         = enum("NetwkTime")

local RouterGroup = class()
local prop = property(RouterGroup)
prop:accessor("master", nil)
prop:accessor("routers", {})
prop:accessor("candidates", {})
prop:accessor("ready_watchers", {})
prop:accessor("close_watchers", {})
function RouterGroup:__init()
    self:setup()
end

--初始化
function RouterGroup:setup()
    --加入更新
    update_mgr:attach_frame(self)
    --心跳定时器
    timer_mgr:loop(NetwkTime.HEARTBEAT_TIME, function()
        for _, node in pairs(self.routers) do
            node.client:heartbeat()
        end
    end)
end

function RouterGroup:release()
end

--添加router
function RouterGroup:add_router(router_conf)
    local router_id = smake_id("router", router_conf.index)
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
    client:send("rpc_service_register", quanta.id)
end

--切换主router
function RouterGroup:switch_master()
    self.candidates = {}
    for _, node in pairs(self.routers) do
        if node.client:is_alive() then
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
function RouterGroup:on_frame()
    local now_tick = quanta.now
    for _, node in pairs(self.routers) do
        local client = node.client
        if not client:is_alive() then
            if now_tick > node.next_connect_time then
                node.next_connect_time = now_tick + NetwkTime.RECONNECT_TIME
                client:connect()
            end
        else
            if client:check_lost(now_tick) then
                log_info("[RouterGroup][on_frame] router lost: %s:%s", client.ip, client.port)
                if node == self.master then
                    self:switch_master()
                end
            end
        end
    end
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
        local hash_code = uhash_code(hash_key, count)
        return self.candidates[hash_code]
    end
end

--通过router发送点对点消息
function RouterGroup:forward_client(router, method, ...)
    if router then
        return router.client:forward_socket(method, ...)
    end
    return false, "router not connected"
end

--通过router发送广播，并收集所有的结果
function RouterGroup:forward_collect(service_id, rpc, ...)
    local collect_res = {}
    local session_id = thread_mgr:build_session_id()
    local ok, code, target_cnt = self:forward_client(self.master, "call_broadcast", session_id, service_id, rpc, ...)
    if ok and check_success(code) then
        while target_cnt > 0 do
            target_cnt = target_cnt - 1
            local ok_c, code_c, res = thread_mgr:yield(session_id, "forward_collect", NetwkTime.RPC_CALL_TIMEOUT)
            if ok_c and check_success(code_c) then
                tinsert(collect_res, res)
            end
        end
    end
    return ok, code, collect_res
end

--通过router传递广播
function RouterGroup:forward_broadcast(service_id, rpc, ...)
    return self:forward_client(self.master, "call_broadcast", 0, service_id, rpc, ...)
end

--发送给指定目标
function RouterGroup:call_target(target, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    return self:forward_client(self:hash_router(target), "call_target", session_id, target, rpc, ...)
end

--发送给指定目标
function RouterGroup:send_target(target, rpc, ...)
    return self:forward_client(self:hash_router(target), "call_target", 0, target, rpc, ...)
end

function RouterGroup:random_call(target, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    return self:forward_client(self:random_router(target), "call_target", session_id, target, rpc, ...)
end

function RouterGroup:random_send(target, rpc, ...)
    return self:forward_client(self:random_router(target), "call_target", 0, target, rpc, ...)
end

function RouterGroup:router_call(router_id, target, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    return self:forward_client(self:get_router(router_id), "call_target", session_id, target, rpc, ...)
end

function RouterGroup:router_send(router_id, target, rpc, ...)
    return self:forward_client(self:get_router(router_id), "call_target", 0, target, rpc, ...)
end

--发送给指定service的hash
function RouterGroup:call_hash(service_id, hash_key, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    return self:forward_client(self:hash_router(hash_key), "call_hash", session_id, service_id, hash_key, rpc, ...)
end

--发送给指定service的hash
function RouterGroup:send_hash(service_id, hash_key, rpc, ...)
    return self:forward_client(self:hash_router(hash_key), "call_hash", 0, service_id, hash_key, rpc, ...)
end

--发送给指定service的master
function RouterGroup:call_master(service_id, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    return self:forward_client(self.master, "call_master", session_id, service_id, rpc, ...)
end

--发送给指定service的master
function RouterGroup:send_master(service_id, rpc, ...)
    return self:forward_client(self.master, "call_master", 0, service_id, rpc, ...)
end

--监听服务断开
function RouterGroup:watch_service_close(listener, service_name)
    if not self.close_watchers[service_name] then
        self.close_watchers[service_name] = {}
    end
    self.close_watchers[service_name][listener] = true
end

--监听服务注册
function RouterGroup:watch_service_ready(listener, service_name)
    if not self.ready_watchers[service_name] then
        self.ready_watchers[service_name] = {}
    end
    self.ready_watchers[service_name][listener] = true
end

--rpc
-------------------------------------------------------------------
--服务器关闭
function RouterGroup:rpc_service_close(id)
    local server_name = sid2name(id)
    local listener_set = self.close_watchers[server_name]
    for listener in pairs(listener_set or {}) do
        listener:on_service_close(id, server_name)
    end
end

--服务器注册
function RouterGroup:rpc_service_ready(id, server_name, router_id)
    local listener_set = self.ready_watchers[server_name]
    for listener in pairs(listener_set or {}) do
        listener:on_service_ready(id, server_name, router_id)
    end
end

return RouterGroup
