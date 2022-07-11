--login_factory.lua

local protobuf_mgr  = quanta.get("protobuf_mgr")
local node_factory  = quanta.get("node_factory")

local Waiting       = import("robot/node/waiting.lua")
local LoginLobby    = import("robot/node/login/login_lobby.lua")
local LoginAccount  = import("robot/node/login/login_account.lua")
local CreatePlayer  = import("robot/node/login/create_player.lua")
local ChoosePlayer  = import("robot/node/login/choose_player.lua")
local LogoutPlayer  = import("robot/node/login/logout_player.lua")
local DeletePlayer  = import("robot/node/login/delete_player.lua")
local CheckPlayer   = import("robot/node/login/check_player.lua")
local LoginSuccess  = import("robot/node/login/login_success.lua")

local BT_LOGIN      = protobuf_mgr:enum("BtNodeId", "BT_LOGIN")
local BT_LOGOUT     = protobuf_mgr:enum("BtNodeId", "BT_LOGOUT")
local BT_LOGIN_UNIT = protobuf_mgr:enum("BtNodeId", "BT_LOGIN_UNIT")
local BT_LOGIN_WAIT = protobuf_mgr:enum("BtNodeId", "BT_LOGIN_WAIT")

local Sequence      = luabt.Sequence

local LoginFactory = singleton()
function LoginFactory:__init()
    node_factory:register_factory(self)
end

function LoginFactory:load()
    node_factory:register(BT_LOGIN, function()
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
            LoginSuccess()
        )
    end)
    node_factory:register(BT_LOGIN_WAIT, function()
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
            LoginSuccess(),
            Waiting()
        )
    end)
    node_factory:register(BT_LOGIN_UNIT, function()
        return Sequence(
            LoginAccount(),
            CreatePlayer(),
            DeletePlayer(),
            CreatePlayer(),
            ChoosePlayer(),
            LoginLobby(),
            LoginSuccess(),
            LogoutPlayer()
        )
    end)
    node_factory:register(BT_LOGOUT, function()
        return LogoutPlayer()
    end)
end

quanta.login_factory = LoginFactory()

return LoginFactory
