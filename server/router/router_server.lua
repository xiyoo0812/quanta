--router_server.lua

local log_err       = logger.err
local log_info      = logger.info
local id2name       = service.id2name

local socket_mgr    = quanta.get("socket_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local RpcServer     = import("network/rpc_server.lua")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local UNREACHABLE   = quanta.enum("KernCode", "RPC_UNREACHABLE")

local RouterServer = singleton()
local prop = property(RouterServer)
prop:reader("rpc_server", nil)
prop:reader("counter", nil)

function RouterServer:__init()
    local inner = environ.get("QUANTA_INNER_IP")
    local ip, port = environ.addr("QUANTA_ROUTER_ADDR")
    local rserver = RpcServer(self, ip, port, true)
    service.make_node(rserver:get_port(), inner)
    self.rpc_server = rserver
    --路由性能统计
    self.counter = quanta.make_sampling("route msg")
    self.counter:set_counter(function()
        local route_count = 0
        local clients = self.rpc_server:get_clients()
        for _, client in pairs(clients) do
            route_count = route_count + client:get_route_count()
        end
        return route_count
    end)
end

--其他服务器节点关闭
function RouterServer:on_client_error(client, client_token, err)
    log_info("[RouterServer][on_client_error] {} lost: {}", client.name, err)
    local new_master = socket_mgr.map_token(client.id)
    log_info("[RouterServer][on_socket_error] {} master --> {}", client.service_name, new_master)
end

--accept事件
function RouterServer:on_client_accept(client)
    log_info("[RouterServer][on_client_accept] new connection, token={}", client.token)
    client.on_forward_error = function(session_id, target_id, source_id, rpc)
        thread_mgr:fork(function()
            local target, source =  id2name(target_id), id2name(source_id)
            log_err("[RouterServer][on_client_accept] on_forward_error, ssid:{}, tar:{}, src:{}, rpc:{})", session_id, target, source, rpc)
            self.rpc_server:callback(client, session_id, false, UNREACHABLE, "router con't find target!")
        end)
    end
    client.on_forward_broadcast = function(session_id, broadcast_num)
        thread_mgr:fork(function()
            self.rpc_server:callback(client, session_id, true, SUCCESS, broadcast_num)
        end)
    end
end

--rpc事件处理
------------------------------------------------------------------
--注册服务器
function RouterServer:on_client_register(client, node, client_id)
    log_info("[RouterServer][on_client_register] service: {}", client.name)
    local new_master = socket_mgr.map_token(client_id, client.token)
    log_info("[RouterServer][on_client_register] {} master --> {}", client.service_name, new_master)
end

-- 会话信息
function RouterServer:on_client_beat(client)
end

quanta.router_server = RouterServer()

return RouterServer
