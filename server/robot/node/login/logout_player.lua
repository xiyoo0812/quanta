--logout_player.lua
local FAIL      = luabt.FAIL
local SUCCESS   = luabt.SUCCESS

local Node      = luabt.Node

local LogoutPlayer = class(Node)
function LogoutPlayer:__init()
    self.name = "logout_player"
end

function LogoutPlayer:run(tree)
    local robot = tree.robot
    if robot:role_logout_req() then
        return SUCCESS
    end
    robot:set_wait_time(200)
    return FAIL
end

return LogoutPlayer
