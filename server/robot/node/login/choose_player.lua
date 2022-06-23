--choose_player.lua
local FAIL      = luabt.FAIL
local SUCCESS   = luabt.SUCCESS

local Node      = luabt.Node

local ChoosePlayer = class(Node)
function ChoosePlayer:__init()
    self.name = "choose_player"
end

function ChoosePlayer:run(tree)
    local robot = tree.robot
    if robot:choose_role_req() then
        return SUCCESS
    end
    robot:set_wait_time(200)
    return FAIL
end

return ChoosePlayer
