--event_component.lua
local xpcall        = xpcall
local log_warn      = logger.warn
local log_fatal     = logger.fatal
local tcopy         = qtable.copy
local qtweak        = qtable.weak
local dtraceback    = debug.traceback

local EventComponent = mixin()
local prop = property(EventComponent)
prop:reader("events", {})

function EventComponent:__init()
end

--添加事件触发器
function EventComponent:watch_event(watcher, event, handler)
    local func_name = handler or event
    local callback_func = watcher[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[EventComponent][watch_event] event({}) handler not define!", event)
        return
    end
    local watcher_map = self.events[event]
    if not watcher_map then
        self.events[event] = qtweak({ [watcher] = func_name })
        return
    end
    watcher_map[watcher] = func_name
end

--添加移除触发器
function EventComponent:unwatch_event(watcher, event)
    local watcher_map = self.events[event]
    if watcher_map then
        watcher_map[watcher] = nil
    end
end

--发布事件
function EventComponent:notify_event(event, ...)
    local watcher_map = tcopy(self.events[event] or {})
    for watcher, func_name in pairs(watcher_map) do
        local callback_func = watcher[func_name]
        local ok, ret = xpcall(callback_func, dtraceback, watcher, ...)
        if not ok then
            log_fatal("[EventComponent][notify_event] xpcall [{}:{}] failed: {}!", watcher:source(), func_name, ret)
        end
    end
end

return EventComponent
