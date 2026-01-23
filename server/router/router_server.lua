--router_server.lua

local log_info      = logger.info
local spolicy       = service.policy
local name2sid      = service.name2sid

local event_mgr     = quanta.get("event_mgr")
local socket_mgr    = quanta.get("socket_mgr")

local RpcServer     = import("network/rpc_server.lua")

local INDUCE        = quanta.enum("PortMode", "INDUCE")

local RouterServer = singleton()
local prop = property(RouterServer)
prop:reader("rpc_server", nil)

function RouterServer:__init()
    local ip, port = environ.addr("QUANTA_ROUTER_ADDR")
    local rserver = RpcServer(self, ip, port, INDUCE)
    service.modify_host(rserver:get_port())
    self.rpc_server = rserver
    --设置目标路由失败后的转发服务
    socket_mgr:set_relay_service(name2sid("online"))
    --注册事件
    event_mgr:add_listener(self, "rpc_service_clean")
    event_mgr:add_listener(self, "rpc_service_online")
end

--其他服务器节点关闭
function RouterServer:on_client_error(client, client_token, err)
    log_info("[RouterServer][on_client_error] {} lost: {}", client.name, err)
    local policy = spolicy(client.service_name)
    local new_master = socket_mgr.map_router(client.id, policy)
    log_info("[RouterServer][on_socket_error] {} master --> {}", client.service_name, new_master)
end

--accept事件
function RouterServer:on_client_accept(client)
    log_info("[RouterServer][on_client_accept] new connection, token={}", client.token)
end

--rpc事件处理
------------------------------------------------------------------
--注册服务器
function RouterServer:on_client_register(client, node, client_id)
    local master_id = socket_mgr.map_router(client_id, client.token)
    local master = self.rpc_server:get_client_by_id(master_id)
    log_info("[RouterServer][on_client_register] {} register! master --> {}", client.name, master.name)
end

--服务清理
function RouterServer:rpc_service_clean(client, player_id)
    log_info("[RouterServer][rpc_service_clean]: {} clean service", player_id)
    socket_mgr.map_client(player_id, 0)
end

--服务上线
function RouterServer:rpc_service_online(client, player_id, services)
    log_info("[RouterServer][rpc_service_online]: {} online: {}", player_id, services)
    for serv_name, serv_id in pairs(services) do
        socket_mgr.map_server(player_id, serv_id, client.token)
    end
end

quanta.router_server = RouterServer()

return RouterServer
