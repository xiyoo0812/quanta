--timer_mgr.lua
local pairs     = pairs
local new_guid  = guid.new
local tunpack   = table.unpack
local tinsert   = table.insert

local thread_mgr = quanta.thread_mgr

local TimerMgr = singleton()
function TimerMgr:__init()
    self.timers = {}
end

function TimerMgr:__update(handle, escape_ms)
    handle.escape = handle.escape + escape_ms
    if handle.escape >= handle.period then
        if handle.times > 0 then
            handle.times = handle.times - (handle.escape // handle.period)
            if handle.times < 0 then
                handle.times = 0
            end
        end
        local escape = handle.escape % handle.period
        local function timer_cb()
            handle.params[#handle.params] = handle.escape - escape
            handle.cb(tunpack(handle.params))
        end
        --防止在定时器中阻塞
        thread_mgr:fork(timer_cb)
        handle.escape = escape
    end
end

function TimerMgr:update(escape_ms)
    for timer_id, handle in pairs(self.timers) do
        if handle.times == 0 then
            self.timers[timer_id] = nil
        else
            self:__update(handle, escape_ms)
        end
    end
end

function TimerMgr:once(period, cb, ...)
    return self:register(period, period, 1, cb, ...)
end

function TimerMgr:loop(period, cb, ...)
    return self:register(period, period, -1, cb, ...)
end

function TimerMgr:register(period, interval, times, cb, ...)
    local params = {...}
    tinsert(params, 0)
    local stimes = times or 1
    local escape = period - interval
    local timer_id = new_guid(period, stimes)
    self.timers[timer_id] = { escape = escape, cb = cb, period = period, times = stimes, params = params }
    return timer_id
end

function TimerMgr:unregister(timer_id)
    self.timers[timer_id] = nil
end

function TimerMgr:clear()
    self.timers = {}
end

quanta.timer_mgr = TimerMgr()

return TimerMgr
