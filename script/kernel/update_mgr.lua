--clock_mgr.lua

local pairs         = pairs
local odate         = os.date
local log_info      = logger.info
local log_warn      = logger.warn
local sig_check     = signal.check
local tunpack       = table.unpack
local collectgarbage= collectgarbage

local event_mgr     = quanta.get("event_mgr")
local timer_mgr     = quanta.get("timer_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local WTITLE        = quanta.worker_title
local FAST_MS       = quanta.enum("PeriodTime", "FAST_MS")
local HALF_MS       = quanta.enum("PeriodTime", "HALF_MS")
local SECOND_5_S    = quanta.enum("PeriodTime", "SECOND_5_S")
local HOTFIXABLE    = environ.status("QUANTA_HOTFIX")

local UpdateMgr = singleton()
local prop = property(UpdateMgr)
prop:reader("last_hour", 0)
prop:reader("last_frame", 0)
prop:reader("last_minute", 0)
prop:reader("last_second", 0)
prop:reader("quit_objs", {})
prop:reader("hour_objs", {})
prop:reader("frame_objs", {})
prop:reader("fast_objs", {})
prop:reader("minute_objs", {})
prop:reader("second_objs", {})
prop:reader("second5_objs", {})
prop:reader("next_events", {})
prop:reader("next_seconds", {})
prop:reader("next_handlers", {})

function UpdateMgr:__init()
    --注册订阅
    self:attach_fast(thread_mgr)
    self:attach_minute(thread_mgr)
    self:attach_frame(timer_mgr)
end

function UpdateMgr:update_next()
    for _, handler in pairs(self.next_handlers) do
        thread_mgr:fork(handler)
    end
    self.next_handlers = {}
    for _, events in pairs(self.next_events) do
        for event, args in pairs(events) do
            thread_mgr:fork(function()
                event_mgr:notify_trigger(event, tunpack(args))
            end)
        end
    end
    self.next_events = {}
end

function UpdateMgr:update_second()
    for _, events in pairs(self.next_seconds) do
        for event, args in pairs(events) do
            thread_mgr:fork(function()
                event_mgr:notify_trigger(event, tunpack(args))
            end)
        end
    end
    self.next_seconds = {}
    --检查文件更新
    if HOTFIXABLE then
        quanta.reload()
    end
    --检查信号
    if not WTITLE then
        self:check_signal()
    end
end

function UpdateMgr:update(now_ms, clock_ms)
    --业务更新
    local diff_ms = clock_ms - quanta.clock_ms
    if diff_ms > HALF_MS then
        log_warn("[UpdateMgr][update] last frame exec too long(%d ms)!", diff_ms)
    end
    --帧更新
    local frame = quanta.frame + 1
    for obj in pairs(self.frame_objs) do
        thread_mgr:fork(function()
            obj:on_frame(clock_ms, frame)
        end)
    end
    quanta.frame = frame
    quanta.now_ms = now_ms
    quanta.clock_ms = clock_ms
    --更新帧逻辑
    self:update_next()
    --快帧200ms更新
    if clock_ms < self.last_frame then
        return
    end
    for obj in pairs(self.fast_objs) do
        thread_mgr:fork(function()
            obj:on_fast(clock_ms)
        end)
    end
    self.last_frame = clock_ms + FAST_MS
    --秒更新
    local now = now_ms // 1000
    if now == quanta.now then
        return
    end
    quanta.now = now
    for obj in pairs(self.second_objs) do
        thread_mgr:fork(function()
            obj:on_second(clock_ms)
        end)
    end
    self:update_second()
    --5秒更新
    if now < self.last_second then
        return
    end
    self.last_second = now + SECOND_5_S
    for obj in pairs(self.second5_objs) do
        thread_mgr:fork(function()
            obj:on_second5(clock_ms)
        end)
    end
    --执行gc
    collectgarbage("step", 1)
    --分更新
    local time = odate("*t", now)
    if time.min == self.last_minute then
        return
    end
    self.last_minute = time.min
    for obj in pairs(self.minute_objs) do
        thread_mgr:fork(function()
            obj:on_minute(clock_ms)
        end)
    end
    --时更新
    local cur_hour = time.hour
    if cur_hour == self.last_hour then
        return
    end
    self.last_hour = cur_hour
    for obj in pairs(self.hour_objs) do
        thread_mgr:fork(function()
            obj:on_hour(clock_ms, cur_hour, time)
        end)
    end
    --gc
    collectgarbage("collect")
    log_info("[UpdateMgr][update]now lua mem: %s!", collectgarbage("count"))
end

function UpdateMgr:check_signal()
    if sig_check() then
        quanta.run = nil
        log_info("[UpdateMgr][check_signal]service quit for signal !")
        for obj in pairs(self.quit_objs) do
            obj:on_quit()
        end
    end
end

--添加对象到小时更新循环
function UpdateMgr:attach_hour(obj)
    if not obj.on_hour then
        log_warn("[UpdateMgr][attach_hour] obj(%s) isn't on_hour method!", obj)
        return
    end
    self.hour_objs[obj] = true
end

function UpdateMgr:detach_hour(obj)
    self.hour_objs[obj] = nil
end

--添加对象到分更新循环
function UpdateMgr:attach_minute(obj)
    if not obj.on_minute then
        log_warn("[UpdateMgr][attach_minute] obj(%s) isn't on_minute method!", obj)
        return
    end
    self.minute_objs[obj] = true
end

function UpdateMgr:detach_minute(obj)
    self.minute_objs[obj] = nil
end

--添加对象到秒更新循环
function UpdateMgr:attach_second(obj)
    if not obj.on_second then
        log_warn("[UpdateMgr][attach_second] obj(%s) isn't on_second method!", obj)
        return
    end
    self.second_objs[obj] = true
end

function UpdateMgr:detach_second(obj)
    self.second_objs[obj] = nil
end

--添加对象到5秒更新循环
function UpdateMgr:attach_second5(obj)
    if not obj.on_second5 then
        log_warn("[UpdateMgr][attach_second5] obj(%s) isn't on_second5 method!", obj)
        return
    end
    self.second5_objs[obj] = true
end

function UpdateMgr:detach_second5(obj)
    self.second5_objs[obj] = nil
end

--添加对象到帧更新循环
function UpdateMgr:attach_frame(obj)
    if not obj.on_frame then
        log_warn("[UpdateMgr][attach_frame] obj(%s) isn't on_frame method!", obj)
        return
    end
    self.frame_objs[obj] = true
end

function UpdateMgr:detach_frame(obj)
    self.frame_objs[obj] = nil
end

--添加对象到快帧更新循环
function UpdateMgr:attach_fast(obj)
    if not obj.on_fast then
        log_warn("[UpdateMgr][attach_fast] obj(%s) isn't on_fast method!", obj)
        return
    end
    self.fast_objs[obj] = true
end

function UpdateMgr:detach_fast(obj)
    self.fast_objs[obj] = nil
end

--下一帧执行一个函数
function UpdateMgr:attach_next(key, func)
    self.next_handlers[key] = func
end

--下一帧执行一个事件
function UpdateMgr:attach_event(key, event, ...)
    local events = self.next_events[key]
    if not events then
        self.next_events[key] = { [event] = { ... } }
        return
    end
    events[event] = { ... }
end

--下一秒执行一个事件
function UpdateMgr:attach_second_event(key, event, ...)
    local events = self.next_seconds[key]
    if not events then
        self.next_seconds[key] = { [event] = { ... } }
        return
    end
    events[event] = { ... }
end

--添加对象到程序退出通知列表
function UpdateMgr:attach_quit(obj)
    if not obj.on_quit then
        log_warn("[UpdateMgr][attach_quit] obj(%s) isn't on_quit method!", obj)
        return
    end
    self.quit_objs[obj] = true
end

function UpdateMgr:detach_quit(obj)
    self.quit_objs[obj] = nil
end

quanta.update_mgr = UpdateMgr()

return UpdateMgr
