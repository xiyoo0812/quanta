-- router_mgr.lua
local lcodec            = require("lcodec")

local pairs             = pairs
local log_err           = logger.err
local log_info          = logger.info
local log_debug         = logger.debug
local tunpack           = table.unpack
local sformat           = string.format
local qsuccess          = quanta.success
local jumphash          = lcodec.jumphash
local signal_quit       = signal.quit

local monitor           = quanta.get("monitor")
local event_mgr         = quanta.get("event_mgr")
local thread_mgr        = quanta.get("thread_mgr")

local RPC_CALL_TIMEOUT  = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local RouterMgr = singleton()
local prop = property(RouterMgr)
prop:reader("routers", {})
prop:reader("candidates", {})

function RouterMgr:__init()
    --router接口
    self:build_service()
    --监听路由信息
    monitor:watch_service_ready(self, "router")
    monitor:watch_service_close(self, "router")
    event_mgr:add_listener(self, "rpc_client_kickout")
end

--服务关闭
function RouterMgr:on_service_close(id, name)
    log_debug("[RouterMgr][on_service_close] node: %s-%s", name, id)
    local router = self.routers[id]
    if router then
        router.client:close()
        self.routers[id] = nil
    end
end

--服务上线
function RouterMgr:on_service_ready(id, name, info)
    log_debug("[RouterMgr][on_service_ready] node: %s-%s, info: %s", name, id, info)
    if info.group == quanta.group then
        self:add_router(info.id, info.ip, info.port)
    end
end

--服务被踢下线
function RouterMgr:rpc_client_kickout(router_id, reason)
    log_err("[RouterMgr][rpc_client_kickout] reason:%s router_id:%s", reason, router_id)
    signal_quit()
end

--添加router
function RouterMgr:add_router(router_id, host, port)
    if not self.routers[router_id] then
        local RpcClient = import("network/rpc_client.lua")
        self.routers[router_id] = {
            addr = host,
            router_id = router_id,
            client = RpcClient(self, host, port)
        }
    end
end

--错误处理
function RouterMgr:on_socket_error(client, token, err)
    log_err("[RouterMgr][on_socket_error] router lost %s:%s, err=%s", client.ip, client.port, err)
    self:check_router()
end

--连接成功
function RouterMgr:on_socket_connect(client, res)
    log_info("[RouterMgr][on_socket_connect] router %s:%s success!", client.ip, client.port)
    self:check_router()
end

--检查可用router
function RouterMgr:check_router()
    local candidates = {}
    for _, node in pairs(self.routers) do
        if node.client:is_alive() then
            candidates[#candidates + 1] = node
        end
    end
    self.candidates = candidates
end

--查找指定router
function RouterMgr:get_router(router_id)
    return self.routers[router_id]
end

--查找hash router
function RouterMgr:hash_router(hash_key)
    local count = #self.candidates
    if count > 0 then
        local index = jumphash(hash_key, count)
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
    local router = self:hash_router(session_id)
    local ok, code, target_cnt = self:forward_client(router, "call_broadcast", session_id, service_id, rpc, ...)
    if qsuccess(code, ok) then
        while target_cnt > 0 do
            target_cnt = target_cnt - 1
            local ok_c, code_c, res = thread_mgr:yield(session_id, "collect", RPC_CALL_TIMEOUT)
            if qsuccess(code_c, ok_c) then
                collect_res[#collect_res + 1] = res
            end
        end
    end
    return ok, code, collect_res
end

--通过router传递广播
function RouterMgr:broadcast(service_id, rpc, ...)
    local router = self:hash_router(service_id)
    return self:forward_client(router, "call_broadcast", 0, service_id, rpc, ...)
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
    for service_id, service in pairs(services) do
        self:build_service_method(service, service_id)
    end
end

quanta.router_mgr = RouterMgr()

return RouterMgr
