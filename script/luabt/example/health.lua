--health.lua

local SUCCESS   = luabt.SUCCESS

local Node      = luabt.Node

local Health = class(Node)
function Health:__init()
    self.name = "health"
end

function Health:run(tree)
    tree.robot.hp = tree.robot.hp + 10
    print(tree.robot.hp, "Health.....")
    return SUCCESS
end

return Health
