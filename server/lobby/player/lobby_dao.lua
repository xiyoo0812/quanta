--lobby_dao.lua
import("agent/mongo_agent.lua")

local log_info      = logger.info

local GameDAO       = import("store/game_dao.lua")

local event_mgr     = quanta.get("event_mgr")

local LobbyDao = singleton(GameDAO)

function LobbyDao:__init()
    event_mgr:add_listener(self, "on_db_prop_update")
    event_mgr:add_listener(self, "on_db_prop_remove")
    self:add_sheet(false, "account", "account.user_id", { account = 1 })
    self:add_sheet(true, "player", "player_id", { player = 1 })
end

function LobbyDao:on_db_prop_update(primary_id, sheet_name, db_key, value)
    log_info("[LobbyDao][on_db_prop_update] primary_id: %s sheet_name: %s, db_key: %s", primary_id, sheet_name, db_key)
    return self:update_field(primary_id, sheet_name, db_key, value, true)
end

function LobbyDao:on_db_prop_remove(primary_id, sheet_name, db_key)
    log_info("[LobbyDao][on_db_prop_remove] primary_id: %s sheet_name: %s, db_key: %s", primary_id, sheet_name, db_key)
    return self:remove_field(primary_id, sheet_name, db_key, true)
end

quanta.lobby_dao = LobbyDao()

return LobbyDao
