--flee.lua

local SUCCESS = luabt.SUCCESS
local RUNNING = luabt.RUNNING

local Flee = class()
function Flee:__init(tick_num)
    self.name = "flee"
    self.tick_num = tick_num
end

function Flee:open(tree)
    if self.tick_num <= 0 then
        return SUCCESS
    end
    print(self.tick_num, "start flee....")
end

function Flee:run(tree)
    self.tick_num = self.tick_num - 1
    tree.robot.hp = tree.robot.hp + 2;
    print(tree.robot.hp, "fleeing.......")
    if self.tick_num <= 0 then
        print(tree.robot.hp, "finish flee")
        return SUCCESS
    end
    return RUNNING
end

function Flee:close(tree)
    print("close flee")
end

return Flee
