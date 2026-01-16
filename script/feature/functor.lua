--functor.lua
local xpcall        = xpcall
local dtraceback    = debug.traceback

local thread_mgr    = quanta.get("thread_mgr")

local Functor = class()
local prop = property(Functor)
prop:reader("time", 0)
prop:reader("name", nil)
prop:reader("functor", nil)

function Functor:__init(func_name, lock_ms)
    self.name = func_name
    if lock_ms > 0 then
        self.functor = function(obj, ...)
            self.time = quanta.clock_ms + lock_ms
            obj[self.name](obj, ...)
            self.time = 0
        end
    end
end

function Functor:call(obj, ...)
    if self.functor then
        if self.time == 0 or self.time <= quanta.clock_ms then
            thread_mgr:fork(self.functor, nil, obj, ...)
        end
    else
        thread_mgr:fork(obj[self.name], nil, obj, ...)
    end
end

function Functor:run(obj, ...)
    return xpcall(obj[self.name], dtraceback, obj, ...)
end

return Functor
