--本文件供除router以外的所有服务进程共同引用
--主要定义了各种rpc工具函数

local RouterGroup   = import("kernel/router/router_group.lua")

local pairs         = pairs
local tindexof      = table_ext.indexof
local ssplit        = string_ext.split
local sid2sid       = service.id2sid
local sname2sid     = service.name2sid
local signal_quit   = signal.quit
local log_err       = logger.err
local log_info      = logger.info

local event_mgr     = quanta.event_mgr
local config_mgr    = quanta.config_mgr
local router_tab    = config_mgr:get_table("router")
local service_tab   = config_mgr:get_table("service")

local RouterMgr = singleton()
function RouterMgr:__init()
    self.index_groups = {}
    self.router_groups = {}
end

--建立router_group索引
function RouterMgr:build_index_groups(group_id, router_group)
    for _, service in service_tab:iterator() do
        if tindexof(service.router_group, group_id) then
            self.index_groups[service.id] = router_group
        end
    end
end

--初始化
function RouterMgr:setup(groups)
    for _, group_id in pairs(groups) do
        for _, router in router_tab:iterator() do
            if group_id == router.group then
                local router_group = self.router_groups[group_id]
                if router_group then
                    router_group:add_router(router)
                else
                    router_group = RouterGroup()
                    router_group:add_router(router)
                    self.router_groups[group_id] = router_group
                    self:build_index_groups(group_id, router_group)
                end
            end
        end
    end
    --注册事件
    event_mgr:add_listener(self, "on_router_update")
    event_mgr:add_listener(self, "on_service_close")
    event_mgr:add_listener(self, "on_service_register")
    event_mgr:add_listener(self, "on_service_kickout")
end

--hash router
function RouterMgr:hash_router(service, hash_key)
    local router_group = self:get_router_group(service)
    if router_group then
        return router_group:hash_router(hash_key)
    end
end

--random router
function RouterMgr:random_router(service_id)
    local router_group = self:get_router_group(service_id)
    if router_group then
        return router_group:random_router()
    end
end

-- 根据目标service_id获取router group对象
function RouterMgr:get_router_group(service_id)
    return self.index_groups[service_id]
end

-- 根据router_id获取router group对象
function RouterMgr:get_router_group_by_id(router_id)
    for _, router_group in pairs(self.router_groups) do
        if router_group.master and router_group.master.router_id == router_id then
            return router_group
        end
    end
end

--代理router_group发送
function RouterMgr:forward_group(method, service_id, ...)
    local router_group = self:get_router_group(service_id)
    if router_group then
        return router_group[method](router_group, ... )
    end
    return false, "router_group not exist"
end

--调用指定目标
function RouterMgr:call_target(target, rpc, ...)
    return self:forward_group("call_target", sid2sid(target), target, rpc, ...)
end

--发送指定目标
function RouterMgr:send_target(target, rpc, ...)
    return self:forward_group("send_target", sid2sid(target), target, rpc, ...)
end

--随机router调用给指定target
function RouterMgr:random_call(target, rpc, ...)
    return self:forward_group("random_call", sid2sid(target), target, rpc, ...)
end

--随机router发送给指定target
function RouterMgr:random_send(target, rpc, ...)
    return self:forward_group("random_send", sid2sid(target), target, rpc, ...)
end

--指定router调用给指定target
function RouterMgr:router_call(router_id, target, rpc, ...)
    return self:forward_group("router_call", sid2sid(target), router_id, target, rpc, ...)
end

--指定router发送给指定target
function RouterMgr:router_send(router_id, target, rpc, ...)
    return self:forward_group("router_send", sid2sid(target), router_id, target, rpc, ...)
end

--发送给指定servic的hash
function RouterMgr:call_hash(service_id, hash_key, rpc, ...)
    return self:forward_group("call_hash", service_id, service_id, hash_key, rpc, ...)
end

--发送给指定servic的hash
function RouterMgr:send_hash(service_id, hash_key, rpc, ...)
    return self:forward_group("send_hash", service_id, service_id, hash_key, rpc, ...)
end

--发送给指定servic的master
function RouterMgr:call_master(service_id, rpc, ...)
    return self:forward_group("call_master", service_id, service_id, rpc, ...)
end

--发送给指定servic的master
function RouterMgr:send_master(service_id, rpc, ...)
    return self:forward_group("send_master", service_id, service_id, rpc, ...)
end

--广播给指定servic
function RouterMgr:forward_broadcast(service_id, rpc, ...)
    return self:forward_group("forward_broadcast", service_id, service_id, rpc, ...)
end

--监听服务断开
function RouterMgr:watch_service_close(listener, service)
    local service_id = sname2sid(service)
    local router_group = self:get_router_group(service_id)
    if router_group then
        router_group:watch_service_close(listener, service_id)
    end
end

--监听服务注册
function RouterMgr:watch_service_register(listener, service)
    local service_id = sname2sid(service)
    local router_group = self:get_router_group(service_id)
    if router_group then
        router_group:watch_service_register(listener, service_id)
    end
end

-- 刷新router配置
function RouterMgr:on_router_update()
    for group_id, router_group in pairs(self.router_groups) do
        self:build_index_groups(group_id, router_group)
        for _, router in router_tab:iterator() do
            if group_id == router.group then
                router_group:add_router(router)
            end
        end
    end
end

--服务关闭
function RouterMgr:on_service_close(quanta_id, router_id)
    local router_group = self:get_router_group_by_id(router_id)
    if router_group then
        router_group:on_service_close(quanta_id)
    end
end

--服务注册
function RouterMgr:on_service_register(quanta_id, service_id, router_id)
    local router_group = self:get_router_group_by_id(router_id)
    if router_group then
        router_group:on_service_register(quanta_id, service_id, router_id)
    end
end

--服务被踢下线
function RouterMgr:on_service_kickout(router_id, kick_ip)
    log_info("[RouterMgr][on_service_kickout] router_id:%s, kick_ip:%s", router_id, kick_ip)
    signal_quit()
end

quanta.router_mgr = RouterMgr()

return RouterMgr