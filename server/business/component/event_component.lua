--event_component.lua
local xpcall        = xpcall
local log_warn      = logger.warn
local log_fatal     = logger.fatal
local tinsert       = table.insert
local tunpack       = table.unpack
local tcopy         = qtable.copy
local qtweak        = qtable.weak
local dtraceback    = debug.traceback

local thread_mgr    = quanta.get("thread_mgr")

local EventComponent = mixin()
local prop = property(EventComponent)
prop:reader("triggers", {})
prop:reader("devents", {})      --dalay events
prop:reader("uevents", {})      --update events

function EventComponent:__init()
end

function EventComponent:add_trigger(trigger, event, handler)
    local func_name = handler or event
    local callback_func = trigger[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[EventComponent][add_trigger] event(%s) handler is nil!", event)
        return
    end
    local trigger_map = self.triggers[event]
    if not trigger_map then
        self.triggers[event] = qtweak({ [trigger] = func_name })
        return
    end
    trigger_map[trigger] = func_name
end

function EventComponent:remove_trigger(trigger, event)
    local trigger_map = self.triggers[event]
    if trigger_map then
        trigger_map[trigger] = nil
    end
end

function EventComponent:notify_event(event, ...)
    local trigger_map = tcopy(self.triggers[event] or {})
    for trigger, func_name in pairs(trigger_map) do
        local callback_func = trigger[func_name]
        local ok, ret = xpcall(callback_func, dtraceback, trigger, ...)
        if not ok then
            log_fatal("[EventComponent][notify_event] xpcall [%s:%s] failed: %s!", trigger:source(), func_name, ret)
        end
    end
end

--延迟通知事件
function EventComponent:delay_notify(event, ...)
    local args = { ... }
    self.devents[event] = function()
        self:notify_event(event, self.id, self, tunpack(args))
    end
end

--发布下次更新处理事件
function EventComponent:fire_update_event(event, ...)
    if type(event) == "function" then
        tinsert(self.uevents, event)
        return
    end
    local args = { ... }
    tinsert(self.uevents, function()
        self:notify_event(event, self, tunpack(args))
    end)
end

--处理延时事件
function EventComponent:_update()
    local devents = self.devents
    self.devents = {}
    for _, handler in pairs(devents) do
        thread_mgr:fork(handler)
    end
    local uevents = self.uevents
    self.uevents = {}
    for _, handler in pairs(uevents) do
        thread_mgr:fork(handler)
    end
end

return EventComponent