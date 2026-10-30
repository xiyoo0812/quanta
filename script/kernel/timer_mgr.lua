--timer_mgr.lua
local log_err   = logger.err
local log_info  = logger.info
local tunpack   = table.unpack
local ltinsert  = timer.insert
local ltupdate  = timer.update
local ltremove  = timer.remove
local ltchange  = timer.change
local lclock_ms = timer.clock_ms
local next_i464 = luakit.next_id64

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

function TimerMgr:trigger(timer_id, handle, clock_ms, remove)
    local args = handle.args
    args[1] = clock_ms - handle.last
    thread_mgr:fork(handle.cb, nil, tunpack(args))
    handle.last = clock_ms
    if remove then
        self.timers[timer_id] = nil
    end
end

function TimerMgr:on_frame(clock_ms)
    local escape_ms = clock_ms - self.last_ms + self.escape_ms
    if escape_ms >= TIMER_ACCURYACY then
        self.last_ms = clock_ms
        self.escape_ms = escape_ms % TIMER_ACCURYACY
        local timers = ltupdate(escape_ms // TIMER_ACCURYACY)
        for i = 1, #timers, 2 do
            local timer_id = timers[i]
            local handle = self.timers[timer_id]
            if handle then
                self:trigger(timer_id, handle, clock_ms, timers[i + 1] == 0)
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

function TimerMgr:register(interval, period_ms, times, cb, ...)
    local period = period_ms // TIMER_ACCURYACY
    if period <= 0 then
        log_err("[TimerMgr][register] period <= 0")
        return
    end
    --生成id并注册
    local args = { 0, ... }
    local reg_ms = lclock_ms()
    local timer_id = next_i464()
    --矫正时间误差
    interval = interval + (reg_ms - self.last_ms)
    ltinsert(timer_id, interval // TIMER_ACCURYACY, period, times)
    --保存信息
    self.timers[timer_id] = { cb = cb, args = args, last = reg_ms }
    return timer_id
end

function TimerMgr:unregister(timer_id)
    local handle = self.timers[timer_id]
    if handle then
        log_info("[TimerMgr][unregister] unregister : {}", timer_id)
        self.timers[timer_id] = nil
        ltremove(timer_id)
    end
end

function TimerMgr:change_period(timer_id, period_ms)
    local period = period_ms // TIMER_ACCURYACY
    local handle = self.timers[timer_id]
    if handle and period > 0 then
        ltchange(timer_id, period)
        return
    end
    log_err("[TimerMgr][change_period] args error: timer_id:{}, period_ms:{}", timer_id, period_ms)
end

quanta.timer_mgr = TimerMgr()

return TimerMgr
