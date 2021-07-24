--timer_mgr.lua
local ltimer    = require("ltimer")
local lcrypt    = require("lcrypt")
local driver    = ltimer.cteate()

local pairs     = pairs
local tpack     = table.pack
local tunpack   = table.unpack
local tinsert   = table.insert
local new_guid  = lcrypt.guid_new
local current_ms= quanta.get_time_ms

local thread_mgr = quanta.get("thread_mgr")

local TimerMgr = singleton()
function TimerMgr:__init()
    self.timers = {}
end

function TimerMgr:trigger(handle, now_ms)
    if handle.times > 0 then
        handle.times = handle.times - 1
    end
    local function timer_cb()
        handle.params[#handle.params] = now_ms - handle.last
        handle.cb(tunpack(handle.params))
    end
    --防止在定时器中阻塞
    thread_mgr:fork(timer_cb)
    --更新定时器数据
    handle.last = now_ms
    if handle.times == 0 then
        self.timers[timer_id] = nil
        return
    end
    --继续注册
    ltimer.insert(driver, timer_id, handle.period)
end

function TimerMgr:update(escape_ms)
    local timers = {}
    local now_ms = current_ms()
    local nsize = ltimer.update(driver, escape_ms, timers)
    for _, timer_id in ipairs(timers) do
        local handle = self.timers[timer_id]
        if handle then
            self:trigger(handle, now_ms)
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
    local timer_id = new_guid(period, interval)
    self.timers[timer_id] = {
        cb = cb,
        times = times,
        period = period,
        last = current_ms(),
        params = tpack(..., 0)
    }
    ltimer.insert(driver, timer_id, interval)
    return timer_id
end

function TimerMgr:unregister(timer_id)
    self.timers[timer_id] = nil
end

function TimerMgr:stop()
    self.timers = {}
    ltimer.release(driver)
end

quanta.timer_mgr = TimerMgr()

return TimerMgr
