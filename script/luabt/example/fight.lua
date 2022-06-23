--fight.lua

local SUCCESS   = luabt.SUCCESS

local Node      = luabt.Node

local Fight = class(Node)
function Fight:__init()
    self.name = "fight"
end

function Fight:run(tree)
    tree.robot.hp = tree.robot.hp - 15
    print(tree.robot.hp, "Fighting.....")
    return SUCCESS
end

return Fight
