--check_player.lua

local Condition = luabt.Condition

local CheckPlayer = class(Condition)
function CheckPlayer:__init(success, failed, count)
    self.name = "check_player"
    self.count = count or 0
end

function CheckPlayer:on_check(tree)
    local robot = tree.robot
    local roles = robot:get_roles()
    return #roles > self.count
end

return CheckPlayer
