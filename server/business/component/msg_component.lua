--msg_component.lua
import("agent/online_agent.lua")

local tunpack       = table.unpack
local qmake_mq      = quanta.make_mq

local online        = quanta.get("online")
local ONL_INLINE    = quanta.enum("OnlineStatus", "INLINE")

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
    self:send_service(serv_name, "rpc_reliable_event")
end

--fire_role_reliable
function MsgComponent:fire_role_reliable(serv_name, target_id, event, ...)
    local msg_queue = self:create_mq(serv_name)
    msg_queue:send_message(target_id, event, { ... })
    self:send_service2role(serv_name, target_id, "rpc_reliable_event")
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

--通过gateway转发消息给client
function MsgComponent:send(cmd_id, data)
    if self.status == ONL_INLINE then
        online:send_client(self.id, self.id, cmd_id, data)
    end
end

--转发消息给role
function MsgComponent:send_service2role(serv_name, role_id, rpc, ...)
    return online:call_service(role_id, rpc, serv_name, role_id, ...)
end

--转发消息给target
function MsgComponent:call_service(serv_name, rpc, ...)
    return online:call_service(self.id, rpc, serv_name, self.id, ...)
end

--转发消息给target
function MsgComponent:send_service(serv_name, rpc, ...)
    online:send_service(self.id, rpc, serv_name, self.id, ...)
end

--转发消息给lobby
function MsgComponent:call_lobby(rpc, ...)
    return online:call_lobby(self.id, rpc, self.id, ...)
end

--转发消息给lobby
function MsgComponent:send_lobby(rpc, ...)
    online:send_lobby(self.id, rpc, self.id, ...)
end

--转发消息给gatwway
function MsgComponent:send_gateway(rpc, ...)
    online:send_gateway(self.id, rpc, self.id, ...)
end

--更新分组信息
function MsgComponent:update_gate_group(group, group_id)
    online:send_gateway(self.id, "rpc_update_group", self.id, group, group_id)
end

return MsgComponent
