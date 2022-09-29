--attribute_set.lua
local tunpack       = table.unpack

local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")

local ReliabledMsg  = import("store/reliable_msg.lua")

local EventSet = mixin()
local prop = property(EventSet)
prop:reader("delegater", nil)   --delegater
prop:reader("event_type", nil)  --event_type

function EventSet:__init()
end

--绑定代理器
--绑定写事件类型，本服务只能写一类事件
function EventSet:bind_delegater(event_type)
    self.event_type = event_type
    self.delegater = ReliabledMsg()
    self.delegater:setup(event_type)
end

--save_event
function EventSet:save_event(target, event_type, ...)
    if self.delegater then
        self.delegater:send_message(self.id, event_type, { ... })
        self:fire_event(target, event_type, true)
    end
end

--fire_event
function EventSet:fire_event(target, event_type, reliable, ...)
    local tar_svr_id = self:find_passkey(target)
    if tar_svr_id then
        router_mgr:call_target(tar_svr_id, "rpc_event_dispatch", self.id, event_type, reliable, ...)
    end
end

--load_events
function EventSet:load_events(event_type)
    local coll_name = event_type or self.event_type
    if not coll_name or not self.delegater then
        return
    end
    local timestamp = 0
    local events = self.delegater:list_message(coll_name, self.id)
    for _, event in pairs(events) do
        if event.time > timestamp then
            timestamp = event.time
        end
        event_mgr:notifyListener(event.event, tunpack(event.args))
    end
    if timestamp > 0 then
        self.delegater:delete_message(coll_name, self.id, timestamp)
    end
end

return EventSet
