--event_component.lua
local log_warn      = logger.warn
local log_fatal     = logger.fatal
local tcopy         = table.copy
local qtweak        = qtable.weak
local make_functer  = quanta.make_functer

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
    local functor = make_functer(func_name, 0)
    if not watcher_map then
        self.events[event] = qtweak({ [functor] = watcher })
        return
    end
    watcher_map[functor] = watcher
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
    for functor, watcher in pairs(watcher_map) do
        local ok, ret = functor:run(watcher, ...)
        if not ok then
            log_fatal("[EventComponent][notify_event] xpcall [{}:{}] failed: {}!", watcher:source(), functor.name, ret)
        end
    end
end

return EventComponent
