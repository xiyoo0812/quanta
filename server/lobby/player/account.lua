--account.lua

local game_dao  = quanta.get("game_dao")

local Account = class()
local prop = property(Account)
prop:reader("user_id", 0)           --user_id
prop:reader("open_id", "")          --open_id
prop:reader("create_time", 0)       --create_time

local dprop = db_property(Account, "account")
dprop:store_value("token", 0)       --token
dprop:store_value("lobby", 0)       --lobby
dprop:store_value("device_id", 0)   --device_id
dprop:store_value("login_time", 0)  --login_time
dprop:store_value("login_token", 0) --login_token
dprop:store_value("reload_token", 0)--reload_token
dprop:store_values("params", {})    --params

function Account:__init(user_id)
    self.user_id = user_id
end

function Account:load()
    local function load_account()
        return game_dao:load(self.user_id, "account")
    end
    return self:load_account_db(self.user_id, load_account)
end

function Account:on_db_account_load(data)
    if data and data.account then
        local account_data = data.account
        self.token = account_data.token
        self.lobby = account_data.lobby
        self.params = account_data.params
        self.open_id = account_data.open_id
        self.device_id = account_data.device_id
        self.login_time = account_data.login_time
        self.create_time = account_data.create_time
        self.login_token = account_data.login_token
        self.reload_token = account_data.reload_token
        return true
    end
    return false
end

return Account
