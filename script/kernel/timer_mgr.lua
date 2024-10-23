--timer_mgr.lua

local ipairs    = ipairs
local tpack     = table.pack
local tunpack   = table.unpack
local new_guid  = codec.guid_new
local lclock_ms = timer.clock_ms
local ltinsert  = timer.insert
local ltupdate  = timer.update

--定时器精度，20ms
local TIMER_ACCURYACY = 20

local thread_mgr    = quanta.get("thread_mgr")

local TimerMgr = singleton()
local prop = property(TimerMgr)
prop:reader("timers", {})
prop:reader("last_ms", 0)
prop:reader("escape_ms", 0)
function TimerMgr:__init()
    self.last_ms = lclock_ms()
end

function TimerMgr:trigger(handle, clock_ms)
    if handle.times > 0 then
        handle.times = handle.times - 1
    end
    --防止在定时器中阻塞
    handle.params[#handle.params] = clock_ms - handle.last
    thread_mgr:fork(handle.cb, tunpack(handle.params))
    --更新定时器数据
    if handle.times == 0 then
        self.timers[handle.timer_id] = nil
        return
    end
    --继续注册
    handle.last = clock_ms
    ltinsert(handle.timer_id, handle.period)
end

function TimerMgr:on_frame(clock_ms)
    local escape_ms = clock_ms - self.last_ms + self.escape_ms
    self.escape_ms = escape_ms % TIMER_ACCURYACY
    self.last_ms = clock_ms
    if escape_ms >= TIMER_ACCURYACY then
        local timers = ltupdate(escape_ms // TIMER_ACCURYACY)
        for _, timer_id in ipairs(timers or {}) do
            local handle = self.timers[timer_id]
            if handle then
                self:trigger(handle, clock_ms)
            end
        end
    end
end

function TimerMgr:once(period, cb, ...)
    return self:register(period, period, 1, cb, ...)
end

function TimerMgr:loop(period, cb, ...)
    return self:register(period, period, -1, cb, ...)
end

function TimerMgr:register(interval, period, times, cb, ...)
    --生成id并注册
    local reg_ms = lclock_ms()
    local timer_id = new_guid(period, interval)
    --矫正时间误差
    interval = interval + (reg_ms - self.last_ms)
    ltinsert(timer_id, interval // TIMER_ACCURYACY)
    --包装回调参数
    local params = tpack(...)
    params[#params + 1] = 0
    --保存信息
    self.timers[timer_id] = {
        cb = cb,
        last = reg_ms,
        times = times,
        params = params,
        timer_id = timer_id,
        period = period // TIMER_ACCURYACY
    }
    return timer_id
end

function TimerMgr:unregister(timer_id)
    self.timers[timer_id] = nil
end

function TimerMgr:set_period(timer_id, period)
    local timer_info = self.timers[timer_id]
    if timer_info then
        timer_info.period = period // TIMER_ACCURYACY
    end
end

function TimerMgr:change_period(timer_id, period)
    local timer_info = self.timers[timer_id]
    if timer_info then
        self.timers[timer_id] = nil
        local new_timer_id = new_guid(period, period)
        timer_info.timer_id = new_timer_id
        timer_info.period = period // TIMER_ACCURYACY
        ltinsert(new_timer_id, timer_info.period)
        self.timers[new_timer_id] = timer_info
        return new_timer_id
    end
    return timer_id
end

quanta.timer_mgr = TimerMgr()

return TimerMgr
