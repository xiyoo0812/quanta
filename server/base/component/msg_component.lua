--msg_component.lua

local tunpack       = table.unpack
local qmake_mq      = quanta.make_mq
local make_functer  = quanta.make_functer

local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")

local MsgComponent = mixin()
local prop = property(MsgComponent)
prop:reader("ldfunctor", nil)   --ldfunctor
prop:reader("msg_queues", {})   --msg_queues

function MsgComponent:__init()
    self.ldfunctor = make_functer("on_load_reliable_events")
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
    if not self.ldfunctor:call(self) then
        event_mgr:publish_frame(self, "load_reliable_events")
    end
end

function MsgComponent:on_load_reliable_events()
    local serv_name = quanta.service_name
    local msg_queue = self:create_mq(serv_name)
    local events = msg_queue:list_message(self.id)
    if events then
        for _, event in ipairs(events) do
            self:notify_event(event.event, tunpack(event.args))
        end
        msg_queue:delete_message(self.id, events)
    end
end

--通过gateway转发消息给client
function MsgComponent:send(cmd_id, data)
    -- if self.status == ONL_INLINE then
    --     online:send_client(self.id, self.id, cmd_id, data)
    -- end
end

--转发消息给role
function MsgComponent:send_service2role(service_id, role_id, rpc, ...)
    return router_mgr:relay_send(role_id, service_id, rpc, role_id, ...)
end

--转发消息给target
function MsgComponent:call_service(service_id, rpc, ...)
    return router_mgr:relay_call(self.id, service_id, rpc, self.id, ...)
end

--转发消息给target
function MsgComponent:send_service(service_id, rpc, ...)
    return router_mgr:relay_send(self.id, service_id, rpc, self.id, ...)
end

--转发消息给gatwway
function MsgComponent:send_gateway(rpc, ...)
    -- online:send_gateway(self.id, rpc, self.id, ...)
end

--更新分组信息
function MsgComponent:update_gate_group(group, group_id)
    -- online:send_gateway(self.id, "rpc_update_group", self.id, group, group_id)
end

return MsgComponent
