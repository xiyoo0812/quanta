--hp_check.lua

local Condition = luabt.Condition

local HpCheck = class(Condition)
function HpCheck:__init(success, failed, hp)
    self.name = "hp_check"
    self.hp = hp
end

function HpCheck:on_check(tree)
    return tree.robot.hp > self.hp
end

return HpCheck
