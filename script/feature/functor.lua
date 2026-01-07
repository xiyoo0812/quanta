--functor.lua
local xpcall        = xpcall
local dtraceback    = debug.traceback

local thread_mgr    = quanta.get("thread_mgr")

local Functor = class()
local prop = property(Functor)
prop:reader("time", 0)
prop:reader("name", nil)
prop:reader("functor", nil)

function Functor:__init(func, lock_ms, name)
    self.name = name
    if lock_ms == 0 then
        self.functor = func
        return
    end
    self.functor = function(...)
        self.time = quanta.clock_ms + lock_ms
        func(...)
        self.time = 0
    end
end

function Functor:call(...)
    if self.time == 0 or self.time <= quanta.clock_ms then
        thread_mgr:fork(self.functor, nil, ...)
    end
end

function Functor:run(...)
    return xpcall(self.functor, dtraceback, ...)
end

return Functor
