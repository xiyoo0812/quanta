--msg_component.lua
import("agent/online_agent.lua")

local tunpack       = table.unpack
local qmake_mq      = quanta.make_mq

local router_mgr    = quanta.get("router_mgr")
local online_agent  = quanta.get("online")

local MsgComponent = mixin()
local prop = property(MsgComponent)
prop:reader("msg_queues", {})   --msg_queues

function MsgComponent:__init()
end

function MsgComponent:create_mq(serv_name)
    local msg_queue = self.msg_queues[serv_name]
    if msg_queue then
        return msg_queue
    end
    msg_queue = qmake_mq()
    msg_queue:setup(serv_name)
    self.msg_queues[serv_name] = msg_queue
    return msg_queue
end

--fire_reliable
function MsgComponent:fire_reliable(serv_name, event, ...)
    local msg_queue = self:create_mq(serv_name)
    msg_queue:send_message(self.id, event, { ... })
    self:send_target(serv_name, "rpc_reliable_event")
end

--fire_online_reliable
function MsgComponent:fire_online_reliable(serv_name, target_id, event, ...)
    local msg_queue = self:create_mq(serv_name)
    msg_queue:send_message(target_id, event, { ... })
    self:send_online_target(serv_name, target_id, "rpc_reliable_event")
end

--fire_lobby_reliable
function MsgComponent:fire_lobby_reliable(event, ...)
    self:fire_reliable("lobby", event, ...)
end

--获取消息长度
function MsgComponent:len_message(target_id, serv_name)
    local msg_queue = self:create_mq(serv_name or quanta.service_name)
    return msg_queue:len_message(target_id)
end

--load_reliable_events
function MsgComponent:load_reliable_events()
    local timestamp = 0
    local serv_name = quanta.service_name
    local msg_queue = self:create_mq(serv_name)
    local events = msg_queue:list_message(self.id)
    for i, event in ipairs(events) do
        if event.time > timestamp then
            timestamp = event.time
        end
        self:notify_event(event.event, tunpack(event.args))
    end
    if timestamp > 0 then
        msg_queue:delete_message(self.id, timestamp)
    end
end

--转发消息给gateway
function MsgComponent:send(cmd_id, data)
    if self.gateway and self.load_success then
        router_mgr:send_target(self.gateway, "rpc_forward_client", self.id, cmd_id, data)
    end
end

--转发消息给target
function MsgComponent:call_target(serv_name, rpc, ...)
    local target_id = self.passkey[serv_name]
    if not target_id then
        return false
    end
    return router_mgr:call_target(target_id, rpc, self.id, ...)
end

--转发消息给target
function MsgComponent:send_target(serv_name, rpc, ...)
    local target_id = self.passkey[serv_name]
    if target_id then
        router_mgr:send_target(target_id, rpc, self.id, ...)
    end
end

--转发消息给target
function MsgComponent:send_online_target(serv_name, target_id, rpc, ...)
    online_agent:call_service(target_id, rpc, serv_name, target_id)
end

--转发消息给lobby
function MsgComponent:call_lobby(rpc, ...)
    return self:call_target("lobby", rpc, ...)
end

--转发消息给lobby
function MsgComponent:send_lobby(rpc, ...)
    self:send_target("lobby", rpc, ...)
end

return MsgComponent