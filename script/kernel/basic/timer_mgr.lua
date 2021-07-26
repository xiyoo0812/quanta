--timer_mgr.lua
local ltimer    = require("ltimer")
local lcrypt    = require("lcrypt")

local pairs     = pairs
local tpack     = table.pack
local tunpack   = table.unpack
local tinsert   = table.insert
local new_guid  = lcrypt.guid_new
local current_ms= quanta.get_time_ms

--定时器精度，10ms
local TIMER_ACCURYACY = 10

local thread_mgr = quanta.get("thread_mgr")

local TimerMgr = singleton()
local prop = property(TimerMgr)
prop:reader("timers", {})
prop:reader("last_ms", 0)
prop:reader("escape_ms", 0)
function TimerMgr:__init()
    self.last_ms = current_ms()
    self.driver = ltimer.create()
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
        self.timers[handle.timer_id] = nil
        return
    end
    --继续注册
    self.driver:insert(handle.timer_id, handle.period)
end

function TimerMgr:update()
    local timers = {}
    local now_ms = current_ms()
    local escape_ms = now_ms - self.last_ms + self.escape_ms
    self.escape_ms = escape_ms % TIMER_ACCURYACY
    self.driver:update(escape_ms // TIMER_ACCURYACY, timers)
    for _, timer_id in ipairs(timers) do
        local handle = self.timers[timer_id]
        if handle then
            self:trigger(handle, now_ms)
        end
    end
    self.last_ms = now_ms
end

function TimerMgr:once(period, cb, ...)
    return self:register(period, period, 1, cb, ...)
end

function TimerMgr:loop(period, cb, ...)
    return self:register(period, period, -1, cb, ...)
end

function TimerMgr:register(interval, period, times, cb, ...)
    --生成id并注册
    local now_ms = current_ms()
    local timer_id = new_guid(period, interval)
    --矫正时间误差
    interval = interval + (now_ms - self.last_ms)
    self.driver:insert(timer_id, interval // TIMER_ACCURYACY)
    --包装回调参数
    local params = tpack(...)
    tinsert(params, 0)
    --保存信息
    self.timers[timer_id] = {
        cb = cb,
        last = now_ms,
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

function TimerMgr:close()
    self.timers = {}
    self.driver:close()
end

quanta.timer_mgr = TimerMgr()

return TimerMgr
