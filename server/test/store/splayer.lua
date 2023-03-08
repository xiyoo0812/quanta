-- etcd_test.lua
local log_debug     = logger.debug

local AAC   = import("test/store/aa_component.lua")
local BBC   = import("test/store/bb_component.lua")

local SPlayer = class(nil, AAC, BBC)
local prop = db_property(SPlayer, "player")
prop:store_value("level", 2)            --level
prop:store_value("name", "")            --name
prop:store_values("games", {})          --games

function SPlayer:__init()
    self:load_player_db()
end

function SPlayer:on_db_player_load(sheet)
    log_debug("[SPlayer][on_db_player_load], sheet:%s", sheet)
end

function SPlayer:on_db_prop_update(sheet, db_key, value)
    log_debug("[SPlayer][on_db_prop_update], sheet:%s, key: %s, value:%s", sheet, db_key, value)
end

function SPlayer:on_db_prop_remove(sheet, db_key)
    log_debug("[SPlayer][on_db_prop_delete], sheet:%s, key: %s", sheet, db_key)
end

return SPlayer
