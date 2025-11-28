--timer_mgr.lua

local ipairs    = ipairs
local tpack     = table.pack
local tunpack   = table.unpack
local ltinsert  = timer.insert
local ltupdate  = timer.update
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

function TimerMgr:trigger(timer_id, handle, clock_ms)
    local times = handle.times
    if times > 0 then
        handle.times = times - 1
    end
    --防止在定时器中阻塞
    local params = handle.params
    params[#params] = clock_ms - handle.last
    thread_mgr:fork(handle.cb, nil, tunpack(params))
    if timer_id == handle.timer_id then
        --更新定时器数据
        if times == 0 then
            self.timers[timer_id] = nil
            return
        end
        --继续注册
        handle.last = clock_ms
        ltinsert(timer_id, handle.period)
    end
end

function TimerMgr:on_frame(clock_ms)
    local escape_ms = clock_ms - self.last_ms + self.escape_ms
    self.escape_ms = escape_ms % TIMER_ACCURYACY
    self.last_ms = clock_ms
    if escape_ms >= TIMER_ACCURYACY then
        local timers = ltupdate(escape_ms // TIMER_ACCURYACY)
        for _, timer_id in ipairs(timers) do
            local handle = self.timers[timer_id]
            if handle then
                self:trigger(timer_id, handle, clock_ms)
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
    local timer_id = next_i464()
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

function TimerMgr:change_period(timer_id, period)
    local handle = self.timers[timer_id]
    if handle then
        local new_period = period // TIMER_ACCURYACY
        if new_period >= handle.period then
            handle.period = new_period
            return timer_id
        end
        self.timers[timer_id] = nil
        local new_timer_id = next_i464()
        handle.timer_id = new_timer_id
        handle.period = new_period
        ltinsert(new_timer_id, new_period)
        self.timers[new_timer_id] = handle
        return new_timer_id
    end
    return timer_id
end

quanta.timer_mgr = TimerMgr()

return TimerMgr
