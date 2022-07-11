--waiting.lua

local Repeat    = luabt.Repeat

local Waiting = class(Repeat)
function Waiting:__init()
    self.name = "waiting"
end

function Waiting:on_check(tree)
    return true
end

return Waiting
