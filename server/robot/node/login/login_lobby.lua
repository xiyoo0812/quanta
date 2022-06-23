--login_lobby.lua
local FAIL      = luabt.FAIL
local SUCCESS   = luabt.SUCCESS

local Node      = luabt.Node

local LoginLobby = class(Node)
function LoginLobby:__init()
    self.name = "login_lobby"
end

function LoginLobby:run(tree)
    local robot = tree.robot
    robot:report("login_lobby_entry")
    if robot:connect_gateway() then
        if robot:role_login_req() then
            return SUCCESS
        end
    end
    robot:set_wait_time(500)
    return FAIL
end

return LoginLobby
