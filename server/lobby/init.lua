--init.lua

local config_mgr = quanta.get("config_mgr")

--初始化配置
config_mgr:init_enum_table("attribute", "AttrID", "id")

--加载
import("store/store_mgr.lua")
import("kernel/gateway_mgr.lua")
import("lobby/player/player_mgr.lua")

import("lobby/servlet/lobby_servlet.lua")
import("lobby/servlet/player_servlet.lua")

import("base/attr/attribute_relay.lua")

