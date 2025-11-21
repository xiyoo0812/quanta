--timer.lua

local timer_mgr     = quanta.get("timer_mgr")

local Timer = class()
local prop = property(Timer)
prop:reader("timer_id", nil)

function Timer:__init()
end

function Timer:__release()
    self:unregister()
end

function Timer:unregister()
    if self.timer_id then
        timer_mgr:unregister(self.timer_id)
    end
end

function Timer:once(period, cb, ...)
    self:unregister()
    self.timer_id = timer_mgr:register(period, period, 1, cb, ...)
end

function Timer:loop(period, cb, ...)
    self:unregister()
    self.timer_id = timer_mgr:register(0, period, -1, cb, ...)
end

function Timer:register(interval, period, times, cb, ...)
    self:unregister()
    self.timer_id = timer_mgr:register(interval, period, times, cb, ...)
end

function Timer:change_period(period)
    local old_timer_id = self.timer_id
    if old_timer_id then
        self.timer_id = timer_mgr:change_period(old_timer_id, period)
    end
end

return Timer
