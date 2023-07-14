--online_agent.lua
local name2sid      = service.name2sid

local router_mgr    = quanta.get("router_mgr")

local SERVICE_LOBBY = name2sid("lobby")
local SERVICE_GATE  = name2sid("gateway")

local OnlineAgent = singleton()
function OnlineAgent:__init()
end

--执行远程rpc消息
function OnlineAgent:login_service(pla_id, ser_name, ser_id)
    return router_mgr:transfor_call(pla_id, 0, "rpc_login_service", pla_id, ser_name, ser_id)
end

function OnlineAgent:query_lobby(pla_id)
    return router_mgr:transfor_call(pla_id, 0, "rpc_query_lobby", pla_id)
end

function OnlineAgent:query_service(pla_id, serv_name)
    return router_mgr:transfor_call(pla_id, 0, "rpc_query_service", pla_id, serv_name)
end

function OnlineAgent:call_lobby(pla_id, rpc, ...)
    return router_mgr:transfor_call(pla_id, SERVICE_LOBBY, rpc, ...)
end

function OnlineAgent:send_lobby(pla_id, rpc, ...)
    return router_mgr:transfor_send(pla_id, SERVICE_LOBBY, rpc, ...)
end

function OnlineAgent:send_gateway(pla_id, rpc, ...)
    return router_mgr:transfor_send(pla_id, SERVICE_GATE, rpc, ...)
end

function OnlineAgent:send_client(pla_id, ...)
    return router_mgr:transfor_send(pla_id, SERVICE_GATE, "rpc_forward_client", ...)
end

function OnlineAgent:call_service(pla_id, rpc, serv_name, ...)
    return router_mgr:transfor_call(pla_id, name2sid(serv_name), rpc, ...)
end

function OnlineAgent:send_service(pla_id, rpc, serv_name, ...)
    return router_mgr:transfor_send(pla_id, name2sid(serv_name), rpc, ...)
end

quanta.online = OnlineAgent()

return OnlineAgent
