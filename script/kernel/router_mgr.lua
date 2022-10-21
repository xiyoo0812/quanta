-- router_mgr.lua
local pairs             = pairs
local qget              = quanta.get
local qenum             = quanta.enum
local log_err           = logger.err
local log_info          = logger.info
local log_debug         = logger.debug
local mrandom           = math.random
local tunpack           = table.unpack
local sformat           = string.format
local qsuccess          = quanta.success
local qhash_code        = quanta.hash_code
local signal_quit       = signal.quit

local monitor           = qget("monitor")
local timer_mgr         = qget("timer_mgr")
local event_mgr         = qget("event_mgr")
local thread_mgr        = qget("thread_mgr")
local update_mgr        = qget("update_mgr")

local HEARTBEAT_TIME    = qenum("NetwkTime", "HEARTBEAT_TIME")
local RECONNECT_TIME    = qenum("NetwkTime", "RECONNECT_TIME")
local RPC_CALL_TIMEOUT  = qenum("NetwkTime", "RPC_CALL_TIMEOUT")

local RouterMgr = singleton()
local prop = property(RouterMgr)
prop:accessor("master", nil)
prop:accessor("routers", {})
prop:accessor("candidates", {})
function RouterMgr:__init()
    self:setup()
end

--初始化
function RouterMgr:setup()
    --router接口
    self:build_service()
    --加入更新
    update_mgr:attach_second(self)
    --心跳定时器
    timer_mgr:loop(HEARTBEAT_TIME, function()
        for _, node in pairs(self.routers) do
            node.client:heartbeat()
        end
    end)
    --监听路由信息
    monitor:watch_service_ready(self, "router")
    monitor:watch_service_close(self, "router")
    event_mgr:add_listener(self, "on_client_kickout")
end

function RouterMgr:on_service_close(id, name)
    log_info("[RouterMgr][on_service_close] name: %s", name)
    local router = self.routers[id]
    if router then
        router.client:close()
        self.routers[id] = nil
    end
end

function RouterMgr:on_service_ready(id, name, info)
    log_debug("[RouterMgr][on_service_ready] id: %s, info: %s", id, info)
    if info.region == quanta.region and info.group == quanta.group then
        self:add_router(info.id, info.ip, info.port)
    end
end

--服务被踢下线
function RouterMgr:on_client_kickout(router_id, reason)
    log_err("[RouterMgr][on_client_kickout] reason:%s router_id:%s", reason, router_id)
    signal_quit()
end

--添加router
function RouterMgr:add_router(router_id, host, port)
    if not self.routers[router_id] then
        local RpcClient = import("network/rpc_client.lua")
        self.routers[router_id] = {
            addr = host,
            router_id = router_id,
            next_connect_time = 0,
            client = RpcClient(self, host, port)
        }
    end
end

--错误处理
function RouterMgr:on_socket_error(client, token, err)
    log_err("[RouterMgr][on_socket_error] router lost %s:%s, err=%s", client.ip, client.port, err)
end

--连接成功
function RouterMgr:on_socket_connect(client, res)
    log_info("[RouterMgr][on_socket_connect] router %s:%s success!", client.ip, client.port)
    --switch master
    self:switch_master()
end

--切换主router
function RouterMgr:switch_master()
    self.candidates = {}
    for _, node in pairs(self.routers) do
        if node.client:is_alive() then
            self.candidates[#self.candidates + 1] = node
        end
    end
    local node = self:random_router()
    if node then
        self.master = node
        log_info("[RouterMgr][switch_master] switch router addr: %s", node.addr)
    end
end

--更新
function RouterMgr:on_second()
    local now_tick = quanta.now
    for _, node in pairs(self.routers) do
        local client = node.client
        if not client:is_alive() then
            if now_tick > node.next_connect_time then
                node.next_connect_time = now_tick + RECONNECT_TIME
                client:connect()
            end
        else
            if client:check_lost(now_tick) then
                log_info("[RouterMgr][on_second] router lost: %s:%s", client.ip, client.port)
                if node == self.master then
                    self:switch_master()
                end
            end
        end
    end
end

--查找指定router
function RouterMgr:get_router(router_id)
    return self.routers[router_id]
end

--查找随机router
function RouterMgr:random_router()
    local count = #self.candidates
    if count > 0 then
        return self.candidates[mrandom(count)]
    end
end

--查找hash router
function RouterMgr:hash_router(hash_key)
    local count = #self.candidates
    if count > 0 then
        local index = qhash_code(hash_key, count)
        return self.candidates[index]
    end
end

--通过router发送点对点消息
function RouterMgr:forward_client(router, method, ...)
    if router then
        return router.client:forward_socket(method, ...)
    end
    return false, "router not connected"
end

--通过router发送广播，并收集所有的结果
function RouterMgr:collect(service_id, rpc, ...)
    local collect_res = {}
    local session_id = thread_mgr:build_session_id()
    local ok, code, target_cnt = self:forward_client(self.master, "call_broadcast", session_id, service_id, rpc, ...)
    if ok and qsuccess(code) then
        while target_cnt > 0 do
            target_cnt = target_cnt - 1
            local ok_c, code_c, res = thread_mgr:yield(session_id, "collect", RPC_CALL_TIMEOUT)
            if ok_c and qsuccess(code_c) then
                collect_res[#collect_res + 1] = res
            end
        end
    end
    return ok, code, collect_res
end

--通过router传递广播
function RouterMgr:broadcast(service_id, rpc, ...)
    return self:forward_client(self.master, "call_broadcast", 0, service_id, rpc, ...)
end

--发送给指定目标
function RouterMgr:call_target(target, rpc, ...)
    if target == quanta.id then
        local res = event_mgr:notify_listener(rpc, ...)
        return tunpack(res)
    end
    local session_id = thread_mgr:build_session_id()
    return self:forward_client(self:hash_router(target), "call_target", session_id, target, rpc, ...)
end

--发送给指定目标
function RouterMgr:send_target(target, rpc, ...)
    if target == quanta.id then
        event_mgr:notify_listener(rpc, ...)
        return true
    end
    return self:forward_client(self:hash_router(target), "call_target", 0, target, rpc, ...)
end

--发送给指定目标
function RouterMgr:random_call(target, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    return self:forward_client(self:random_router(), "call_target", session_id, target, rpc, ...)
end

--发送给指定目标
function RouterMgr:random_send(target, rpc, ...)
    return self:forward_client(self:random_router(), "call_target", 0, target, rpc, ...)
end

--指定路由发送给指定目标
function RouterMgr:router_call(router_id, target, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    return self:forward_client(self:get_router(router_id), "call_target", session_id, target, rpc, ...)
end

--指定路由发送给指定目标
function RouterMgr:router_send(router_id, target, rpc, ...)
    return self:forward_client(self:get_router(router_id), "call_target", 0, target, rpc, ...)
end

--发送给指定service的hash
function RouterMgr:call_hash(service_id, hash_key, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    return self:forward_client(self:hash_router(hash_key), "call_hash", session_id, service_id, hash_key, rpc, ...)
end

--发送给指定service的hash
function RouterMgr:send_hash(service_id, hash_key, rpc, ...)
    return self:forward_client(self:hash_router(hash_key), "call_hash", 0, service_id, hash_key, rpc, ...)
end

--发送给指定service的hash
function RouterMgr:random_hash(service_id, hash_key, rpc, ...)
    return self:forward_client(self:random_router(hash_key), "call_hash", 0, service_id, hash_key, rpc, ...)
end

--发送给指定service的master
function RouterMgr:call_master(service_id, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    return self:forward_client(self:hash_router(service_id), "call_master", session_id, service_id, rpc, ...)
end

--发送给指定service的master
function RouterMgr:send_master(service_id, rpc, ...)
    return self:forward_client(self:hash_router(service_id), "call_master", 0, service_id, rpc, ...)
end

--生成针对服务的访问接口
function RouterMgr:build_service_method(service, service_id)
    local method_list = {
        ["call_%s_hash"] = function(obj, hash_key, rpc, ...)
            return obj:call_hash(service_id, hash_key, rpc, ...)
        end,
        ["send_%s_hash"] = function(obj, hash_key, rpc, ...)
            return obj:send_hash(service_id, hash_key, rpc, ...)
        end,
        ["random_%s_hash"] = function(obj, hash_key, rpc, ...)
            return obj:random_hash(service_id, hash_key, rpc, ...)
        end,
        ["call_%s_master"] = function(obj, rpc, ...)
            return obj:call_master(service_id, rpc, ...)
        end,
        ["send_%s_master"] = function(obj, rpc, ...)
            return obj:send_master(service_id, rpc, ...)
        end,
        ["call_%s_all"] = function(obj, rpc, ...)
            return obj:broadcast(service_id, rpc, ...)
        end,
        ["collect_%s"] = function(obj, rpc, ...)
            return obj:collect(service_id, rpc, ...)
        end,
    }
    for fmt_key, handler in pairs(method_list) do
        local method = sformat(fmt_key, service)
        if not RouterMgr[method] then
            RouterMgr[method] = handler
        end
    end
end

--生成针对服务的访问接口
function RouterMgr:build_service()
    local services = service.services()
    for service, service_id in pairs(services) do
        self:build_service_method(service, service_id)
    end
end

quanta.router_mgr = RouterMgr()

return RouterMgr
