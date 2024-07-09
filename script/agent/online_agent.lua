--online_agent.lua
local qfailed       = quanta.failed
local name2sid      = service.name2sid

local router_mgr    = quanta.get("router_mgr")

local SERVICE_LOBBY = name2sid("lobby")
local SERVICE_GATE  = name2sid("gateway")

local OnlineAgent = singleton()
function OnlineAgent:__init()
end

function OnlineAgent:is_online(pla_id)
    local ok, code, lobby_id = router_mgr:call_router(pla_id, "rpc_query_lobby", pla_id)
    if qfailed(code, ok) then
        return false
    end
    return lobby_id > 0
end

function OnlineAgent:query_lobby(pla_id)
    local ok, code, lobby_id = router_mgr:call_router(pla_id, "rpc_query_lobby", pla_id)
    if qfailed(code, ok) then
        return ok
    end
    return ok, lobby_id or 0
end

function OnlineAgent:query_service(pla_id, serv_name)
    local ok, code, service_id = router_mgr:call_router(pla_id, "rpc_query_service", pla_id, serv_name)
    if qfailed(code, ok) then
        return 0
    end
    return service_id or 0
end

function OnlineAgent:call_lobby(pla_id, rpc, ...)
    return router_mgr:forward_call(pla_id, SERVICE_LOBBY, rpc, ...)
end

function OnlineAgent:send_lobby(pla_id, rpc, ...)
    return router_mgr:forward_send(pla_id, SERVICE_LOBBY, rpc, ...)
end

function OnlineAgent:send_gateway(pla_id, rpc, ...)
    return router_mgr:forward_send(pla_id, SERVICE_GATE, rpc, ...)
end

function OnlineAgent:send_client(pla_id, ...)
    return router_mgr:forward_send(pla_id, SERVICE_GATE, "rpc_forward_client", ...)
end

function OnlineAgent:call_service(pla_id, rpc, serv_name, ...)
    return router_mgr:forward_call(pla_id, name2sid(serv_name), rpc, ...)
end

function OnlineAgent:send_service(pla_id, rpc, serv_name, ...)
    return router_mgr:forward_send(pla_id, name2sid(serv_name), rpc, ...)
end

quanta.online = OnlineAgent()

return OnlineAgent
