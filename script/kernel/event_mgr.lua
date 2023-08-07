--event_mgr.lua
local tinsert       = table.insert
local tunpack       = table.unpack
local log_warn      = logger.warn

local thread_mgr    = quanta.get("thread_mgr")

local Listener      = import("basic/listener.lua")

local EventMgr = singleton(Listener)
local prop = property(EventMgr)
prop:reader("fevent_set", {})       -- frame event set
prop:reader("sevent_set", {})       -- second event set
prop:reader("fevent_map", {})       -- frame event map
prop:reader("sevent_map", {})       -- second event map
prop:reader("invalidates", {})      -- invalidates
function EventMgr:__init()
end

function EventMgr:on_frame()
    local handlers = self.fevent_set
    self.fevent_set = {}
    for _, handler in pairs(handlers) do
        thread_mgr:fork(handler)
    end
    for obj, events in pairs(self.fevent_map) do
        for event, args in pairs(events) do
            thread_mgr:fork(function()
                obj:notify_event(event, obj, tunpack(args))
            end)
        end
    end
    self.fevent_map = {}
    local tick = quanta.now
    for obj, func in pairs(self.invalidates) do
        thread_mgr:fork(function()
            obj[func](obj, tick)
        end)
    end
    self.invalidates = {}
end

function EventMgr:on_second()
    local handlers = self.sevent_set
    self.sevent_set = {}
    for _, handler in pairs(handlers) do
        thread_mgr:fork(handler)
    end
    for obj, events in pairs(self.sevent_map) do
        for event, args in pairs(events) do
            thread_mgr:fork(function()
                obj:notify_event(event, obj, tunpack(args))
            end)
        end
    end
    self.sevent_map = {}
end

--invalidate
function EventMgr:invalidate(obj, func)
    if not obj[func] then
        log_warn("[EventMgr][invalidate] obj(%s) isn't %s method!", obj:source(), func)
        return
    end
    self.invalidates[obj] = func
end

--下一帧发布
function EventMgr:publish_frame(obj, event, ...)
    if not self.fevent_map[obj] then
        self.fevent_map[obj] = {[event] = { ... }}
    end
    self.fevent_map[obj][event] = { ... }
end

--下一秒发布
function EventMgr:publish_second(obj, event, ...)
    if not self.sevent_map[obj] then
        self.sevent_map[obj] = {[event] = { ... }}
    end
    self.sevent_map[obj][event] = { ... }
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

-- export
quanta.event_mgr = EventMgr()

return EventMgr