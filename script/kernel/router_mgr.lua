-- router_mgr.lua

local pairs             = pairs
local log_err           = logger.err
local log_info          = logger.info
local log_debug         = logger.debug
local tsort             = table.sort
local tunpack           = table.unpack
local sformat           = string.format
local lnext_id          = luakit.next_id
local qsuccess          = quanta.success
local hash_code         = codec.hash_code
local signal_quit       = signal.quit

local event_mgr         = quanta.get("event_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local discover          = quanta.load("discover")

local FLAG_REQ          = quanta.enum("FlagMask", "REQ")
local RPC_CALL_TIMEOUT  = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local RouterMgr = singleton()
local prop = property(RouterMgr)
prop:reader("routers", {})
prop:reader("candidates", {})

function RouterMgr:__init()
    --router接口
    self:build_service()
    --监听服务退出
    event_mgr:add_listener(self, "rpc_service_kickout")
    --监听路由信息
    if discover and environ.status("QUANTA_ROUTER") then
        discover:watch_service(self, "router")
    end
end

--服务关闭
function RouterMgr:on_service_close(id, name)
    log_debug("[RouterMgr][on_service_close] node: {}-{}", name, id)
    local router = self.routers[id]
    if router then
        router:set_holder(nil)
    end
end

--服务上线
function RouterMgr:on_service_ready(id, name, info)
    log_debug("[RouterMgr][on_service_ready] node: {}-{}, info: {}", name, id, info)
    self:add_router(info.id, info.host, info.port)
end

--服务被踢下线
function RouterMgr:rpc_service_kickout(router_id, reason)
    log_err("[RouterMgr][rpc_service_kickout] reason:{} router_id:{}", reason, router_id)
    signal_quit()
end

--注册服务
function RouterMgr:login_service(pla_id, ser_name, ser_id)
    return self:call_router(pla_id, "rpc_login_service", pla_id, ser_name, ser_id)
end

--添加router
function RouterMgr:add_router(router_id, host, port)
    local router = self.routers[router_id]
    if router then
        router:relocation(self, host, port)
        return
    end
    local RpcClient = import("network/rpc_client.lua")
    self.routers[router_id] = RpcClient(self, host, port, router_id)
end

--错误处理
function RouterMgr:on_socket_error(client, token, err)
    log_err("[RouterMgr][on_socket_error] router lost {}:{}, err={}", client.ip, client.port, err)
    self:check_router()
end

--连接成功
function RouterMgr:on_socket_connect(client, res)
    log_info("[RouterMgr][on_socket_connect] router {}:{} success!", client.ip, client.port)
    client:register()
    self:check_router()
    event_mgr:notify_trigger("on_router_connected")
end

function RouterMgr:available()
    return #self.candidates > 0
end

--检查可用router
function RouterMgr:check_router()
    local candidates = {}
    for _, client in pairs(self.routers) do
        if client:is_alive() then
            candidates[#candidates + 1] = client
        end
    end
    tsort(candidates, function(a, b) return a.id < b.id end)
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
        local index = hash_code(hash_key, count)
        return self.candidates[index]
    end
end

--发送router消息
function RouterMgr:forward_call(target_id, service_id, ...)
    local router = self:hash_router(target_id)
    if router then
        local session_id = lnext_id()
        return router:forward_transfer(target_id, session_id, service_id, ...)
    end
    return false, "router not connected"
end

--发送router消息
function RouterMgr:forward_send(target_id, service_id, ...)
    local router = self:hash_router(target_id)
    if router then
        return router:forward_transfer(target_id, 0, service_id, ...)
    end
    return false, "router not connected"
end

--通过router发送点对点消息
function RouterMgr:forward_target(router, method, rpc, ...)
    if router then
        return router:forward_socket(method, rpc, ...)
    end
    return false, "router not connected"
end

--通过router发送广播，并收集所有的结果
function RouterMgr:collect(service_id, rpc, ...)
    local collect_res = {}
    local session_id = lnext_id()
    local router = self:hash_router(session_id)
    local ok, code, target_cnt = self:forward_target(router, "call_broadcast", rpc, session_id, service_id, ...)
    if qsuccess(code, ok) then
        while target_cnt > 0 do
            target_cnt = target_cnt - 1
            local ok_c, code_c, res = thread_mgr:yield(session_id, rpc, RPC_CALL_TIMEOUT)
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
    return self:forward_target(router, "call_broadcast", rpc, 0, service_id, ...)
end

--发送给指定目标
function RouterMgr:call_target(target, rpc, ...)
    if target == quanta.id then
        local res = event_mgr:notify_listener(rpc, ...)
        return tunpack(res)
    end
    local session_id = lnext_id()
    return self:forward_target(self:hash_router(target), "call_target", rpc, session_id, target, ...)
end

--发送给指定目标
function RouterMgr:call_target_hash(target, hash_key, rpc, ...)
    if target == quanta.id then
        local res = event_mgr:notify_listener(rpc, ...)
        return tunpack(res)
    end
    local session_id = lnext_id()
    return self:forward_target(self:hash_router(hash_key), "call_target", rpc, session_id, target, ...)
end

--发送给指定目标
function RouterMgr:send_target(target, rpc, ...)
    if target == quanta.id then
        event_mgr:notify_listener(rpc, ...)
        return true
    end
    return self:forward_target(self:hash_router(target), "call_target", rpc, 0, target, ...)
end

--发送给指定目标
function RouterMgr:send_target_hash(target, hash_key, rpc, ...)
    if target == quanta.id then
        event_mgr:notify_listener(rpc, ...)
        return true
    end
    return self:forward_target(self:hash_router(hash_key), "call_target", rpc, 0, target, ...)
end

--发送给路由
function RouterMgr:call_router_id(router_id, rpc, ...)
    local session_id = lnext_id()
    return self:forward_target(self:get_router(router_id), "call_rpc", rpc, session_id, FLAG_REQ, ...)
end

--发送给路由
function RouterMgr:send_router_id(router_id, rpc, ...)
    return self:forward_target(self:get_router(router_id), "call_rpc", rpc, 0, FLAG_REQ, ...)
end

--发送给路由
function RouterMgr:call_router(hash_key, rpc, ...)
    local session_id = lnext_id()
    return self:forward_target(self:hash_router(hash_key), "call_rpc", rpc, session_id, FLAG_REQ, ...)
end

--发送给路由
function RouterMgr:send_router(hash_key, rpc, ...)
    return self:forward_target(self:hash_router(hash_key), "call_rpc", rpc, 0, FLAG_REQ, ...)
end

--发送给指定service的hash
function RouterMgr:call_hash(service_id, hash_key, rpc, ...)
    local session_id = lnext_id()
    return self:forward_target(self:hash_router(hash_key), "call_hash", rpc, session_id, service_id, hash_key, ...)
end

--发送给指定service的hash
function RouterMgr:send_hash(service_id, hash_key, rpc, ...)
    return self:forward_target(self:hash_router(hash_key), "call_hash", rpc, 0, service_id, hash_key, ...)
end

--发送给指定service的master
function RouterMgr:call_master(service_id, rpc, ...)
    local session_id = lnext_id()
    return self:forward_target(self:hash_router(service_id), "call_master", rpc, session_id, service_id, ...)
end

--发送给指定service的master
function RouterMgr:send_master(service_id, rpc, ...)
    return self:forward_target(self:hash_router(service_id), "call_master", rpc, 0, service_id, ...)
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
