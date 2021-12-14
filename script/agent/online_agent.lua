--online_agent.lua
local tunpack       = table.unpack

local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")

local KernCode      = enum("KernCode")

local OnlineAgent = singleton()
function OnlineAgent:__init()
    event_mgr:add_listener(self, "rpc_forward_client")
end

--执行远程rpc消息
function OnlineAgent:login_player(player_id)
    return router_mgr:call_online_hash(player_id, "rpc_login_player", player_id, quanta.id)
end

function OnlineAgent:logout_player(player_id)
    return router_mgr:call_online_hash(player_id, "rpc_logout_player", player_id)
end

function OnlineAgent:query_player(player_id)
    return router_mgr:call_online_hash(player_id, "rpc_query_player", player_id)
end

--无序
function OnlineAgent:router_message(player_id, rpc, ...)
    return router_mgr:send_online_random("rpc_router_message", player_id, rpc, ...)
end

--有序
function OnlineAgent:transfer_message(player_id, rpc, ...)
    return router_mgr:call_online_hash(player_id, "rpc_transfer_message", player_id, rpc, ...)
end

--有序
function OnlineAgent:forward_message(player_id, ...)
    return router_mgr:call_online_hash(player_id, "rpc_forward_message", player_id, ...)
end

--rpc处理
------------------------------------------------------------------
function OnlineAgent:rpc_forward_client(player_id, ...)
    local ok, res = tunpack(event_mgr:notify_listener("on_forward_client", player_id, ...))
    return ok and KernCode.SUCCESS or KernCode.SUCCESS , res
end

quanta.online = OnlineAgent()

return OnlineAgent
