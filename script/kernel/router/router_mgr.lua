--本文件供除router以外的所有服务进程共同引用
--主要定义了各种rpc工具函数

local Listener      = import("base/listener.lua")
local RouterGroup   = import("kernel/router/router_group.lua")

local pairs         = pairs
local ssplit        = quanta_extend.split
local sget_group    = service.get_group
local sgroup_name   = service.get_group_by_name
local services      = service.groups
local log_err       = logger.err
local log_info      = logger.info

local ROUTER_GROUP_CFG = import("config/router_cfg.lua")

local RouterMgr = singleton(Listener)
function RouterMgr:__init()
    self.index_groups = {}
    self.router_groups = {}
end

--初始化
function RouterMgr:setup(group_cfg)
    log_info("[RouterMgr][setup] group_cfg: %s", group_cfg)
    local group_id_cfgs = ssplit(group_cfg, ',')
    if #group_id_cfgs == 0 then
        log_err("[RouterMgr][setup] find group_cfg empty! svr_name:%s", quanta.name)
        os.exit(1)
    end
    for _, group_id in pairs(group_id_cfgs) do
        local router_cfg = ROUTER_GROUP_CFG[tonumber(group_id)]
        if router_cfg then
            local check_router_group = false
            local router_group = RouterGroup(router_cfg.routers_addr)
            --建立router_group索引
            for _, service_name in pairs(router_cfg.svr_names) do
                local service_group = sgroup_name(service_name)
                self.index_groups[service_group] = router_group
                if service_name == quanta.name then
                    check_router_group = true
                end
            end
            -- 检查配置
            if check_router_group then
                log_info("[RouterMgr][setup] find service group failed! group_name:%s", router_cfg.name)
                os.exit(1)
            end
            log_info("[RouterMgr][setup] load router group:%s", group_id)
            self.router_groups[group_id] = router_group
        end
    end

    --注册事件
    self:add_listener(self, "on_heartbeat")
    self:add_listener(self, "on_server_close")
    self:add_listener(self, "on_server_register")
    self:add_listener(self, "on_server_kickout")
    --添加帧更新
    quanta.join(self)
end

--更新
function RouterMgr:update()
    for _, router_group in pairs(self.router_groups) do
        router_group:update()
    end
end

--hash router
function RouterMgr:hash_router(group, hash_key)
    local router_group = self:get_router_group(group)
    if router_group then
        return router_group:hash_router(hash_key)
    end
end

--random router
function RouterMgr:random_router(group)
    local router_group = self:get_router_group(group)
    if router_group then
        return router_group:random_router()
    end
end

-- 根据目标service group获取router group对象
function RouterMgr:get_router_group(target_group)
    return self.index_groups[target_group]
end

-- 根据router_id获取router group对象
function RouterMgr:get_router_group_by_id(router_id)
    for _, router_group in pairs(self.router_groups) do
        if router_group.master and router_group.master.router_id == router_id then
            return router_group
        end
    end
end

--代理group发送
function RouterMgr:forward_group(method, group, ...)
    local router_group = self:get_router_group(group)
    if router_group then
        return router_group[method](router_group, ... )
    end
    return false, "router_group not exist"
end

--发送给指定目标
function RouterMgr:call_target(target, rpc, ...)
    return self:forward_group("call_target", sget_group(target), target, rpc, ...)
end

--发送给指定目标
function RouterMgr:send_target(target, rpc, ...)
    return self:forward_group("send_target", sget_group(target), target, rpc, ...)
end

--类似于call_target,但是不走当前router,而是随机
--注意,有时序不一致的风险,如果调用此函数,请确保你知道意味着什么
--一般用于分散出口流量,减少单个进程往某个router输出流量过大的风险
function RouterMgr:random_call(target, rpc, ...)
    return self:forward_group("random_call", sget_group(target), target, rpc, ...)
end

function RouterMgr:random_send(target, rpc, ...)
    return self:forward_group("random_send", sget_group(target), target, rpc, ...)
end

function RouterMgr:router_call(router_id, target, rpc, ...)
    return self:forward_group("router_call", sget_group(target), router_id, target, rpc, ...)
end

function RouterMgr:router_send(router_id, target, rpc, ...)
    return self:forward_group("router_send", sget_group(target), router_id, target, rpc, ...)
end

--发送给指定组的hash
function RouterMgr:call_hash(group, hash_key, rpc, ...)
    return self:forward_group("call_hash", group, group, hash_key, rpc, ...)
end

--发送给指定组的hash
function RouterMgr:send_hash(group, hash_key, rpc, ...)
    return self:forward_group("send_hash", group, group, hash_key, rpc, ...)
end

--发送给指定组的master
function RouterMgr:call_master(group, rpc, ...)
    return self:forward_group("call_master", group, group, rpc, ...)
end

--发送给指定组的master
function RouterMgr:send_master(group, rpc, ...)
    return self:forward_group("send_master", group, group, rpc, ...)
end

function RouterMgr:forward_broadcast(group, rpc, ...)
    return self:forward_group("forward_broadcast", group, group, rpc, ...)
end

-- 刷新router配置
function RouterMgr:update_router_cfg(group_id)
    local router_group = self.router_groups[group_id]
    if router_group then
        local router_cfg = ROUTER_GROUP_CFG[group_id]
        router_group:update_routers(router_cfg.routers_addr)
        --建立router_group索引
        for _, service_name in pairs(router_cfg.svr_names) do
            local service_group = sgroup_name(service_name)
            self.index_groups[service_group] = router_group
        end
    end
end

--监听服务器断开
function RouterMgr:watch_server_close(listener, group)
    local router_group = self:get_router_group(group)
    if router_group then
        router_group:watch_server_close(listener, group)
    end
end

--监听服务器注册
function RouterMgr:watch_server_register(listener, group)
    local router_group = self:get_router_group(group)
    if router_group then
        router_group:watch_server_register(listener, group)
    end
end

--事件监听
----------------------------------------------------------------
function RouterMgr:on_heartbeat()
    --暂不处理
end

function RouterMgr:on_server_close(id, router_id)
    local router_group = self:get_router_group_by_id(router_id)
    if router_group then
        router_group:on_server_close(id)
    end
end

function RouterMgr:on_server_register(id, group, router_id)
    local router_group = self:get_router_group_by_id(router_id)
    if router_group then
        router_group:on_server_register(id, group, router_id)
    end
end

function RouterMgr:on_server_kickout(router_id, kick_ip)
    log_info("[RouterMgr][on_server_kickout] router_id:%s, kick_ip:%s", router_id, kick_ip)
    signal_quit()
end

quanta.router_mgr = RouterMgr()

return RouterMgr
