--flee.lua

local SUCCESS   = luabt.SUCCESS

local Node      = luabt.Node

local Flee = class(Node)
function Flee:__init()
    self.name = "flee"
end

function Flee:run(tree)
    tree.robot.hp = tree.robot.hp + 2
    print(tree.robot.hp, "Flee.....")
    return SUCCESS
end

return Flee
