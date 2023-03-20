--account.lua

local game_dao  = quanta.get("game_dao")

local Account = class()
local prop = property(Account)
prop:reader("user_id", 0)           --user_id
prop:reader("open_id", "")          --open_id
prop:reader("create_time", 0)       --create_time

local dprop = db_property(Account, "account", true)
dprop:store_value("token", 0)       --token
dprop:store_value("lobby", 0)       --lobby
dprop:store_value("device_id", 0)   --device_id
dprop:store_value("login_time", 0)  --login_time
dprop:store_value("login_token", 0) --login_token
dprop:store_value("params", {})     --params
dprop:store_values("roles", {})     --roles

function Account:__init(open_id)
    self.open_id = open_id
end

function Account:load()
    return game_dao:load_group(self, "account", self.open_id)
end

function Account:on_db_account_load(data)
    if data and data.account then
        local account_data = data.account
        self.token = account_data.token
        self.lobby = account_data.lobby
        self.roles = account_data.roles
        self.params = account_data.params
        self.user_id = account_data.user_id
        self.device_id = account_data.device_id
        self.login_time = account_data.login_time
        self.create_time = account_data.create_time
        self.login_token = account_data.login_token
        return true
    end
    return false
end

function Account:update_nick(role_id, name)
    local role = self.roles[role_id]
    if role then
        role.name = name
        self:set_roles_field(role_id, role)
    end
end

function Account:update_custom(role_id, custom)
    local role = self.roles[role_id]
    if role then
        role.custom = custom
        self:set_roles_field(role_id, role)
    end
end

return Account
