--login_mgr.lua

local LoginLobby    = import("robot/node/login/login_lobby.lua")
local LoginAccount  = import("robot/node/login/login_account.lua")
local CreatePlayer  = import("robot/node/login/create_player.lua")
local ChoosePlayer  = import("robot/node/login/choose_player.lua")
local LogoutPlayer  = import("robot/node/login/logout_player.lua")
local DeletePlayer  = import("robot/node/login/delete_player.lua")
local CheckPlayer   = import("robot/node/login/check_player.lua")

local Sequence      = luabt.Sequence

local LoginMgr = singleton()
function LoginMgr:__init()
end

--创建登陆流程的行为树
function LoginMgr:create_login()
    return Sequence(
        LoginAccount(),
        CheckPlayer(
            ChoosePlayer(),
            Sequence(
                CreatePlayer(),
                ChoosePlayer()
            )
        ),
        LoginLobby(),
        LogoutPlayer()
    )
end

--创建登陆功能测试的行为树
function LoginMgr:create_login_test()
    return Sequence(
        LoginAccount(),
        CreatePlayer(),
        DeletePlayer(),
        CreatePlayer(),
        ChoosePlayer(),
        LoginLobby(),
        LogoutPlayer()
    )
end

quanta.login_mgr = LoginMgr()

return LoginMgr
