--clock_mgr.lua

local pairs         = pairs
local odate         = os.date
local log_info      = logger.info
local log_warn      = logger.warn
local sig_get       = signal.get
local sig_check     = signal.check
local sig_reload    = signal.reload
local tunpack       = table.unpack
local tinsert       = table.insert
local collectgarbage= collectgarbage

local event_mgr     = quanta.get("event_mgr")
local timer_mgr     = quanta.get("timer_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local HOTFIXABLE    = environ.status("QUANTA_HOTFIX")

local FAST_MS       = quanta.enum("PeriodTime", "FAST_MS")
local HALF_MS       = quanta.enum("PeriodTime", "HALF_MS")

local UpdateMgr = singleton()
local prop = property(UpdateMgr)
prop:reader("last_hour", 0)
prop:reader("last_frame", 0)
prop:reader("last_minute", 0)
prop:reader("quit_objs", {})
prop:reader("hour_objs", {})
prop:reader("frame_objs", {})
prop:reader("fast_objs", {})
prop:reader("minute_objs", {})
prop:reader("second_objs", {})
prop:reader("second5_objs", {})
prop:reader("second30_objs", {})
prop:reader("next_events", {})
prop:reader("next_seconds", {})
prop:reader("next_handlers", {})

function UpdateMgr:__init()
    --注册订阅
    self:attach_fast(thread_mgr)
    self:attach_frame(timer_mgr)
    self:attach_second(thread_mgr)
    self:attach_minute(thread_mgr)
end

function UpdateMgr:update_next()
    local next_events = self.next_events
    local next_handlers = self.next_handlers
    self.next_events = {}
    self.next_handlers = {}
    for _, handler in pairs(next_handlers) do
        thread_mgr:fork(handler)
    end
    for _, events in pairs(next_events) do
        for event, args in pairs(events) do
            thread_mgr:fork(function()
                event_mgr:notify_trigger(event, tunpack(args))
            end)
        end
    end
end

function UpdateMgr:update_second(clock_ms)
    for obj, address in pairs(self.second_objs) do
        thread_mgr:entry(address, function()
            obj:on_second(clock_ms)
        end)
    end
    local next_seconds = self.next_seconds
    self.next_seconds = {}
    for _, events in pairs(next_seconds) do
        for event, args in pairs(events) do
            thread_mgr:fork(function()
                event_mgr:notify_trigger(event, tunpack(args))
            end)
        end
    end
end

function UpdateMgr:update(scheduler, now_ms, clock_ms)
    --业务更新
    local diff_ms = clock_ms - quanta.clock_ms
    quanta.clock_ms = clock_ms
    quanta.now_ms = now_ms
    if diff_ms > HALF_MS then
        log_warn("[UpdateMgr][update] last frame exec too long(%d ms)!", diff_ms)
    end
    --帧更新
    local frame = quanta.frame + 1
    for obj, address in pairs(self.frame_objs) do
        thread_mgr:entry(address, function()
            obj:on_frame(clock_ms, frame)
        end)
    end
    quanta.frame = frame
    --更新帧逻辑
    self:update_next()
    --快帧100ms更新
    if clock_ms < self.last_frame then
        return
    end
    for obj, address in pairs(self.fast_objs) do
        thread_mgr:entry(address, function()
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
    --热更检查
    if HOTFIXABLE then
        quanta.reload()
    end
    --信号检查
    self:check_signal(scheduler)
    --时间更新
    self:update_second(clock_ms)
    self:update_by_time(now, clock_ms)
end

function UpdateMgr:update_by_time(now, clock_ms)
    --5秒更新
    local time = odate("*t", now)
    if time.sec % 5 > 0 then
        return
    end
    for obj in pairs(self.second5_objs) do
        thread_mgr:fork(function()
            obj:on_second5(clock_ms)
        end)
    end
    --30秒更新
    if time.sec % 30 > 0 then
        return
    end
    for obj in pairs(self.second30_objs) do
        thread_mgr:fork(function()
            obj:on_second30(clock_ms)
        end)
    end
    --执行gc
    collectgarbage("step", 10)
    --分更新
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
    --每日4点执行一次全量更新
    if cur_hour == 4 then
        collectgarbage("collect")
    end
    log_info("[UpdateMgr][update]now lua mem: %s!", collectgarbage("count"))
end

function UpdateMgr:check_signal(scheduler)
    if scheduler then
        local signal = sig_get()
        if sig_reload(signal) then
            log_info("[UpdateMgr][check_signal]service reload for signal !")
            --重新加载脚本
            quanta.reload()
            --事件通知
            event_mgr:notify_trigger("on_reload")
            --通知woker更新
            scheduler:broadcast("on_reload")
        end
        if sig_check(signal) then
            log_info("[UpdateMgr][check_signal]service quit for signal !")
            for obj in pairs(self.quit_objs) do
                obj:on_quit()
            end
            --通知woker退出
            scheduler:quit()
            --退出
            quanta.run = nil
        end
    end
end

--添加对象到小时更新循环
function UpdateMgr:attach_hour(obj)
    if not obj.on_hour then
        log_warn("[UpdateMgr][attach_hour] obj(%s) isn't on_hour method!", obj:source())
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
        log_warn("[UpdateMgr][attach_minute] obj(%s) isn't on_minute method!", obj:source())
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
        log_warn("[UpdateMgr][attach_second] obj(%s) isn't on_second method!", obj:source())
        return
    end
    self.second_objs[obj] = obj:address()
end

function UpdateMgr:detach_second(obj)
    self.second_objs[obj] = nil
end

--添加对象到5秒更新循环
function UpdateMgr:attach_second5(obj)
    if not obj.on_second5 then
        log_warn("[UpdateMgr][attach_second5] obj(%s) isn't on_second5 method!", obj:source())
        return
    end
    self.second5_objs[obj] = true
end

function UpdateMgr:detach_second5(obj)
    self.second5_objs[obj] = nil
end

--添加对象到30秒更新循环
function UpdateMgr:attach_second30(obj)
    if not obj.on_second30 then
        log_warn("[UpdateMgr][attach_second30] obj(%s) isn't on_second30 method!", obj:source())
        return
    end
    self.second30_objs[obj] = true
end

function UpdateMgr:detach_second30(obj)
    self.second30_objs[obj] = nil
end

--添加对象到帧更新循环
function UpdateMgr:attach_frame(obj)
    if not obj.on_frame then
        log_warn("[UpdateMgr][attach_frame] obj(%s) isn't on_frame method!", obj:source())
        return
    end
    self.frame_objs[obj] = obj:address()
end

function UpdateMgr:detach_frame(obj)
    self.frame_objs[obj] = nil
end

--添加对象到快帧更新循环
function UpdateMgr:attach_fast(obj)
    if not obj.on_fast then
        log_warn("[UpdateMgr][attach_fast] obj(%s) isn't on_fast method!", obj:source())
        return
    end
    self.fast_objs[obj] = obj:address()
end

function UpdateMgr:detach_fast(obj)
    self.fast_objs[obj] = nil
end

--下一帧执行一个函数
function UpdateMgr:attach_next(func)
    tinsert(self.next_handlers, func)
end

--下一帧执行一个事件
function UpdateMgr:attach_event(eid, event, ...)
    local events = self.next_events[eid]
    if not events then
        self.next_events[eid] = { [event] = { ... } }
        return
    end
    events[event] = { ... }
end

--下一秒执行一个事件
function UpdateMgr:attach_second_event(eid, event, ...)
    local events = self.next_seconds[eid]
    if not events then
        self.next_seconds[eid] = { [event] = { ... } }
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
