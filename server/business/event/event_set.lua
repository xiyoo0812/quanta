--attribute_set.lua
local xpcall        = xpcall
local log_err       = logger.err
local log_warn      = logger.warn
local tremove       = table.remove
local tunpack       = table.unpack
local dtraceback    = debug.traceback

local EVENT_NAME    = "reliable_events"

local router_mgr    = quanta.get("router_mgr")

local ReliableMsg   = import("store/reliable_msg.lua")

local EventSet = mixin()
local prop = property(EventSet)
prop:reader("triggers", {})
prop:reader("delegater", nil)   --delegater

function EventSet:__init()
    self.delegater = ReliableMsg()
    self.delegater:setup(EVENT_NAME)
end

--转发消息给gateway
function EventSet:send(cmd_id, data)
    if not self.gateway then
        log_warn("[EventSet][send] player(%s-%s) gateway is nil!", self.id, cmd_id)
        return
    end
    router_mgr:send_target(self.gateway, "rpc_forward_client", self.id, cmd_id, data)
end

--转发消息给target
function EventSet:call_target(target, rpc, ...)
    local target_id = self.passkey[target]
    if not target_id then
        return false
    end
    return router_mgr:call_target(target_id, rpc, self.id, ...)
end

--转发消息给target
function EventSet:send_target(target, rpc, ...)
    local target_id = self.passkey[target]
    if target_id then
        router_mgr:send_target(target_id, rpc, self.id, ...)
    end
end

--转发消息给lobby
function EventSet:call_lobby(rpc, ...)
    return self:call_target("lobby", rpc, ...)
end

--转发消息给lobby
function EventSet:send_lobby(rpc, ...)
    self:send_target("lobby", rpc, ...)
end

--fire_reliable
function EventSet:fire_reliable(target, event, ...)
    self.delegater:send_message(self.id, event, { ... })
    self:send_target(target, "rpc_reliable_event")
end

--fire_lobby_reliable
function EventSet:fire_lobby_reliable(event, ...)
    self.delegater:send_message(self.id, event, { ... })
    self:send_lobby("rpc_reliable_event")
end

--load_events
function EventSet:load_reliable_events()
    local timestamp = 0
    local coll_name = EVENT_NAME
    local events = self.delegater:list_message(coll_name, self.id)
    for _, event in pairs(events) do
        if event.time > timestamp then
            timestamp = event.time
        end
        self:notify_event(event.event, tunpack(event.args))
    end
    if timestamp > 0 then
        self.delegater:delete_message(coll_name, self.id, timestamp)
    end
end

function EventSet:add_trigger(trigger, event)
    local callback_func = trigger[event]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[EventSet][add_trigger] event(%s) handler is nil!", event)
        return
    end
    local info = { trigger, event }
    local triggers = self.triggers[event]
    if not triggers then
        self.triggers[event] = { info }
        return
    end
    triggers[#triggers + 1] = info
end

function EventSet:remove_trigger(trigger, event)
    local trigger_array = self.triggers[event]
    if trigger_array then
        for i, context in pairs(trigger_array or {}) do
            if context[1] == trigger then
                tremove(trigger_array, i)
            end
        end
    end
end

function EventSet:notify_event(event, ...)
    for _, trigger_ctx in ipairs(self.triggers[event] or {}) do
        local trigger, func_name = tunpack(trigger_ctx)
        local callback_func = trigger[func_name]
        local ok, ret = xpcall(callback_func, dtraceback, trigger, ...)
        if not ok then
            log_err("[EventSet][notify_event] xpcall [%s:%s] failed: %s!", trigger:source(), func_name, ret)
        end
    end
end

return EventSet
