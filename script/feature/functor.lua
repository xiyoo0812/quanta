--functor.lua

local thread_mgr    = quanta.get("thread_mgr")
local SECOND_30_MS  = quanta.enum("PeriodTime", "SECOND_30_MS")

local Functor = class()
local prop = property(Functor)
prop:reader("time", 0)
prop:reader("functor", nil)

function Functor:__init(func, reenter)
    if reenter then
        self.functor = func
        return
    end
    self.functor = function(...)
        self.time = quanta.clock_ms + SECOND_30_MS
        func(...)
        self.time = 0
    end
end

function Functor:call(...)
    if self.time > quanta.clock_ms then
        return false
    end
    thread_mgr:fork(self.functor, nil, ...)
    return true
end

return Functor
