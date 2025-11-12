--event_mgr.lua
local xpcall        = xpcall
local log_warn      = logger.warn
local log_fatal     = logger.fatal
local qtweak        = qtable.weak
local tinsert       = table.insert
local tunpack       = table.unpack
local dtraceback    = debug.traceback

local thread_mgr    = quanta.get("thread_mgr")

local Listener      = import("basic/listener.lua")

local EventMgr = singleton(Listener)
local prop = property(EventMgr)
prop:reader("hooks", {})            -- hooks set
prop:reader("fevent_set", {})       -- frame event set
prop:reader("sevent_set", {})       -- second event set
prop:reader("fevent_map", {})       -- frame event map
prop:reader("sevent_map", {})       -- second event map
prop:reader("fnotify_map", {})      -- frame notify map
prop:reader("snotify_map", {})      -- second notify map
function EventMgr:__init()
end

function EventMgr:on_frame()
    local handlers = self.fevent_set
    self.fevent_set = {}
    for _, handler in pairs(handlers) do
        thread_mgr:fork(handler)
    end
    local mhandlers = self.fevent_map
    self.fevent_map = {}
    for obj, events in pairs(mhandlers) do
        for event in pairs(events) do
            thread_mgr:fork(obj[event], nil, obj)
        end
    end
    local nhandlers = self.fnotify_map
    self.fnotify_map = {}
    for obj, events in pairs(nhandlers) do
        for event, args in pairs(events) do
            thread_mgr:fork(obj.notify_event, nil, event, obj, tunpack(args))
        end
    end
end

function EventMgr:on_second()
    local handlers = self.sevent_set
    self.sevent_set = {}
    for _, handler in pairs(handlers) do
        thread_mgr:fork(handler)
    end
    local mhandlers = self.sevent_map
    self.sevent_map = {}
    for obj, events in pairs(mhandlers) do
        for event in pairs(events) do
            thread_mgr:fork(obj[event], nil, obj)
        end
    end
    local nhandlers = self.snotify_map
    self.snotify_map = {}
    for obj, events in pairs(nhandlers) do
        for event, args in pairs(events) do
            thread_mgr:fork(obj.notify_event, nil, event, obj, tunpack(args))
        end
    end
end

function EventMgr:register_hook(listener, name, handler)
    if self.hooks[name] then
        log_warn("[EventMgr][register_hook] hook({}) repeat!", name)
        return
    end
    local func_name = handler or name
    local callback_func = listener[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[EventMgr][register_hook] hook({}) handler not define!", name)
        return
    end
    self.hooks[name] = qtweak({ [listener] = func_name })
end

function EventMgr:execute_hook(name, ...)
    local hooker_map = self.hooks[name] or {}
    for hooker, func_name in pairs(hooker_map) do
        local callback_func = hooker[func_name]
        local ok, ret = xpcall(callback_func, dtraceback, hooker, ...)
        if not ok then
            log_fatal("[EventMgr][notify_trigger] xpcall [{}:{}] failed: {}!", hooker:source(), func_name, ret)
        end
    end
end

--下一帧发布
function EventMgr:publish_frame(obj, event)
    if not self.fevent_map[obj] then
        self.fevent_map[obj] = {[event] = true}
    end
    self.fevent_map[obj][event] = true
end

--下一秒发布
function EventMgr:publish_second(obj, event)
    if not self.sevent_map[obj] then
        self.sevent_map[obj] = {[event] = true}
    end
    self.sevent_map[obj][event] = true
end

--延迟一帧事件
function EventMgr:fire_frame(event, ...)
    if type(event) == "function" then
        tinsert(self.fevent_set, event)
        return
    end
    local args = { ... }
    tinsert(self.fevent_set, function()
        self:notify_trigger(event, tunpack(args))
    end)
end

--延迟一秒事件
function EventMgr:fire_second(event, ...)
    if type(event) == "function" then
        tinsert(self.sevent_set, event)
        return
    end
    local args = { ... }
    tinsert(self.sevent_set, function()
        self:notify_trigger(event, tunpack(args))
    end)
end

--下一帧发布
function EventMgr:notify_frame(obj, event, ...)
    if not self.fnotify_map[obj] then
        self.fnotify_map[obj] = {[event] = {...}}
    end
    self.fnotify_map[obj][event] = {...}
end

--下一秒发布
function EventMgr:notify_second(obj, event, ...)
    if not self.snotify_map[obj] then
        self.snotify_map[obj] = {[event] = {...}}
    end
    self.snotify_map[obj][event] = {...}
end

-- export
quanta.event_mgr = EventMgr()

return EventMgr