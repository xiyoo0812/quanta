--online_mgr.lua

local pairs         = pairs
local log_info      = logger.info
local log_debug     = logger.debug

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local discover      = quanta.get("discover")
local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")

local OnlineMgr = singleton()
local prop = property(OnlineMgr)
prop:reader("player_services", {})

function OnlineMgr:__init()
    --初始化，注册事件
    event_mgr:add_listener(self, "rpc_player_logout")
    event_mgr:add_listener(self, "rpc_query_service")
    event_mgr:add_listener(self, "rpc_service_online")
    --注册hook
    event_mgr:register_hook(self, "on_rpc_recv")
end

--注册服务
function OnlineMgr:watch_service(service_name)
    discover:watch_service(self, service_name)
end

--服务关闭
function OnlineMgr:on_service_close(serv_id, serv_name)
    log_debug("[OnlineMgr][on_service_close]: {}-{}", serv_name, serv_id)
    for player_id, services in pairs(self.player_services) do
        services[serv_name] = nil
    end
end


function OnlineMgr:on_rpc_recv(hook, rpc, router_id, player_id)
    if rpc == "rpc_service_online" then
        local services = self.player_services[player_id] or {}
        services.router = router_id
        self.player_services[player_id] = services
        local router = router_mgr:get_router(router_id)
        router:send("rpc_service_online", player_id, services)
    end
end

--rpc协议处理
------------------------------------------------------------------------------
--玩家服务上线
function OnlineMgr:rpc_service_online(player_id, service_name, server_id)
    log_info("[OnlineMgr][rpc_service_online]: {}, {}", player_id, service_name)
    local services = self.player_services[player_id] or {}
    services[service_name] = server_id
    self.player_services[player_id] = services
    return SUCCESS
end

--角色登出
function OnlineMgr:rpc_player_logout(player_id)
    log_info("[OnlineMgr][rpc_player_logout]: %s", player_id)
    self.player_services[player_id] = nil
    return SUCCESS
end

--查询玩家某个服务的token
function OnlineMgr:rpc_query_service(player_id, service_name)
    local services = self.player_services[player_id] or {}
    return SUCCESS, services[service_name] or 0
end

-------------------------------------------------------------------
--消息转发
function OnlineMgr:on_relay_message(router_id, session_id, player_id, service_id, source, rpc, ...)
    local services = self.player_services[player_id] or {}
    local orouter_id = services.router
    if orouter_id then
        local router = router_mgr:get_router(orouter_id)
        if router then
            router:send("rpc_service_clean", player_id)
        end
    end
    services.router = router_id
    local router = router_mgr:get_router(orouter_id)
    router:send("rpc_service_online", player_id, services)
    router:relay(player_id, session_id, service_id, source, rpc, ...)
end

-- export
quanta.online_mgr = OnlineMgr()

return OnlineMgr

