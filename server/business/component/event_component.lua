--event_component.lua
local xpcall        = xpcall
local log_warn      = logger.warn
local log_fatal     = logger.fatal
local tinsert       = table.insert
local tremove       = table.remove
local tunpack       = table.unpack
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
    local info = qtweak({ trigger, func_name })
    local triggers = self.triggers[event]
    if not triggers then
        self.triggers[event] = { info }
        return
    end
    triggers[#triggers + 1] = info
end

function EventComponent:remove_trigger(trigger, event)
    local trigger_array = self.triggers[event]
    if trigger_array then
        for i, context in pairs(trigger_array or {}) do
            if context[1] == trigger then
                tremove(trigger_array, i)
                return
            end
        end
    end
end

function EventComponent:notify_event(event, ...)
    for _, trigger_ctx in ipairs(self.triggers[event] or {}) do
        local trigger, func_name = tunpack(trigger_ctx)
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