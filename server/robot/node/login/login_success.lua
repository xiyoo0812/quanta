--login_success.lua

local Repeat    = luabt.Repeat

local LoginSuccess = class(Repeat)
function LoginSuccess:__init()
    self.name = "login_success"
end

function LoginSuccess:on_check(tree)
    local robot = tree.robot
    if robot:is_login_success() then
        return false
    end
    return true
end

return LoginSuccess
