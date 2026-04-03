--account.lua

local store_mgr = quanta.get("store_mgr")

local Account = class()
local prop = property(Account)
prop:reader("open_id", "")          --open_id
prop:accessor("params", {})         --params
prop:accessor("user_id", 0)         --user_id
prop:accessor("channel","")         --channel
prop:accessor("device_id", 0)       --device_id
prop:accessor("create_time", 0)     --create_time

local store = storage(Account, "account")
store:store_value("lobby", 0)       --lobby
store:store_values("players", {})   --players

function Account:__init(open_id)
    self.open_id = open_id
end

function Account:load()
    return store_mgr:load(self, self.open_id, "account")
end

function Account:on_db_account_load(data)
    if data.open_id then
        self:set_lobby(data.lobby)
        self:set_players(data.players)
        self:set_params(data.params)
        self:set_user_id(data.user_id)
        self:set_device_id(data.device_id)
        self:set_create_time(data.create_time)
        self:set_channel(data.channel or "default")
        return true
    end
    return false
end

function Account:update_nick(player_id, name)
    local player = self.players[player_id]
    if player then
        player.name = name
        self:save_players_field(player_id, player)
    end
end

function Account:update_facade(player_id, facade)
    local player = self.players[player_id]
    if player then
        player.facade = facade
        self:save_players_field(player_id, player)
    end
end

return Account
