--login_account.lua
local FAIL      = luabt.FAIL
local SUCCESS   = luabt.SUCCESS

local Node      = luabt.Node

local LoginAccount = class(Node)
function LoginAccount:__init()
    self.name = "login_account"
end

function LoginAccount:run(tree)
    local robot = tree.robot
    robot:report("login_account_entry")
    if robot:connect_login() then
        if robot:account_login_req() then
            return SUCCESS
        end
    end
    robot:set_wait_time(500)
    return FAIL
end

return LoginAccount
