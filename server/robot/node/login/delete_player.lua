--delete_player.lua
local FAIL      = luabt.FAIL
local SUCCESS   = luabt.SUCCESS

local Node      = luabt.Node

local DeletePlayer = class(Node)
function DeletePlayer:__init()
    self.name = "delete_player"
end

function DeletePlayer:run(tree)
    local robot = tree.robot
    if robot:delete_role_req() then
        return SUCCESS
    end
    robot:set_wait_time(200)
    return FAIL
end

return DeletePlayer
