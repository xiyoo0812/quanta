--online_agent.lua
local log_info      = logger.info
local sidhash       = service.hash
local sid2index     = service.id2index
local get_service   = service.get_service

local monitor       = quanta.get("monitor")
local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")

local OnlineAgent = singleton()
function OnlineAgent:__init()
    monitor:watch_service_ready(self, "online")
end

--执行远程rpc消息
function OnlineAgent:login_player(player, serv_data)
    local pla_id = player:get_id()
    local gateway = player:get_gateway()
    return router_mgr:call_online_hash(pla_id, "rpc_login_player", pla_id, gateway, serv_data)
end

function OnlineAgent:logout_player(pla_id)
    return router_mgr:call_online_hash(pla_id, "rpc_logout_player", pla_id)
end

function OnlineAgent:query_lobby(pla_id)
    return router_mgr:call_online_hash(pla_id, "rpc_query_lobby", pla_id)
end

function OnlineAgent:query_service(pla_id, serv_name)
    return router_mgr:call_online_hash(pla_id, "rpc_query_service", pla_id, serv_name)
end

function OnlineAgent:call_lobby(pla_id, rpc, ...)
    return router_mgr:call_online_hash(pla_id, "rpc_call_lobby", pla_id, rpc, ...)
end

function OnlineAgent:send_lobby(pla_id, rpc, ...)
    return router_mgr:random_online_hash(pla_id, "rpc_send_lobby", pla_id, rpc, ...)
end

function OnlineAgent:call_client(pla_id, ...)
    return router_mgr:call_online_hash(pla_id, "rpc_call_client", pla_id, ...)
end

function OnlineAgent:send_client(pla_id, ...)
    return router_mgr:random_online_hash(pla_id, "rpc_send_client", pla_id, ...)
end

function OnlineAgent:call_service(pla_id, rpc, serv_name, ...)
    return router_mgr:call_online_hash(pla_id, "rpc_call_service", pla_id, rpc, serv_name, ...)
end

function OnlineAgent:send_service(pla_id, rpc, serv_name, ...)
    return router_mgr:random_online_hash(pla_id, "rpc_send_service", pla_id, rpc, serv_name, ...)
end

-- Online服务已经ready
function OnlineAgent:on_service_ready(id, service_name)
    log_info("[OnlineAgent][on_service_ready]->id:%s, service_name:%s", id, service_name)
    --[[local service_id = get_service(id)
    local servive_index = sid2index(id)
    local service_hash = sidhash(service_id)
    event_mgr:notify_listener("on_rebuild_online", service_hash, servive_index)]]
end

quanta.online = OnlineAgent()

return OnlineAgent
