--online_agent.lua
local log_info      = logger.info
local tunpack       = table.unpack
local sidhash       = service.hash
local sid2sid       = service.id2sid
local sid2index     = service.id2index

local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")

local KernCode      = enum("KernCode")

local OnlineAgent = singleton()
function OnlineAgent:__init()
    event_mgr:add_listener(self, "rpc_forward_client")
    router_mgr:watch_service_ready(self, "online")
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

function OnlineAgent:router_message(player_id, rpc, ...)
    return router_mgr:random_online_hash(player_id, "rpc_router_message", player_id, rpc, ...)
end

function OnlineAgent:transfer_message(player_id, rpc, ...)
    return router_mgr:call_online_hash(player_id, "rpc_transfer_message", player_id, rpc, ...)
end

function OnlineAgent:send_transfer_message(player_id, rpc, ...)
    return router_mgr:send_online_hash(player_id, "rpc_send_transfer_message", player_id, rpc, ...)
end

function OnlineAgent:forward_message(player_id, ...)
    return router_mgr:call_online_hash(player_id, "rpc_forward_message", player_id, ...)
end

function OnlineAgent:send_forward_message(player_id, ...)
    return router_mgr:random_online_hash(player_id, "rpc_send_forward_message", player_id, ...)
end

--rpc处理
------------------------------------------------------------------
--透传给client的消息
--需由player_mgr实现on_forward_client，给client发消息
function OnlineAgent:rpc_forward_client(player_id, ...)
    local ok, res = tunpack(event_mgr:notify_listener("on_forward_client", player_id, ...))
    return ok and KernCode.SUCCESS or KernCode.LOGIC_FAILED , res
end

-- Online服务已经ready
function OnlineAgent:on_service_ready(id, service_name)
    log_info("[OnlineAgent][on_service_ready]->id:%s, service_name:%s", id, service_name)
    local service_id = sid2sid(id)
    local servive_index = sid2index(id)
    local service_hash = sidhash(service_id)
    event_mgr:notify_listener("on_rebuild_online", service_hash, servive_index)
end

quanta.online = OnlineAgent()

return OnlineAgent
