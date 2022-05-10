--attack.lua

local SUCCESS = luabt.SUCCESS
local RUNNING = luabt.RUNNING

local Attack = class()
function Attack:__init(tick_num)
    self.name = "attack"
    self.tick_num = tick_num
end

function Attack:open(tree)
    if self.tick_num <= 0 then
        return SUCCESS
    end
    print(self.tick_num, "start attack...")
end

function Attack:run(tree)
    self.tick_num = self.tick_num - 1
    tree.robot.hp = tree.robot.hp - 1;
    print(tree.robot.hp, "attacking.....")
    if self.tick_num <= 0 then
        print(tree.robot.hp, "attack finish!")
        return SUCCESS
    end
    return RUNNING
end

function Attack:close(tree)
    print("close attack")
end

return Attack
