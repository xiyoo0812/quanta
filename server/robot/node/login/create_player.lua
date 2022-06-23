--create_player.lua
local FAIL      = luabt.FAIL
local SUCCESS   = luabt.SUCCESS

local Node      = luabt.Node

local CreatePlayer = class(Node)
function CreatePlayer:__init()
    self.name = "create_player"
end

function CreatePlayer:run(tree)
    local robot = tree.robot
    local name = robot:random_name_req()
    if name then
        if robot:create_role_req(name) then
            return SUCCESS
        end
    end
    robot:set_wait_time(200)
    return FAIL
end

return CreatePlayer
