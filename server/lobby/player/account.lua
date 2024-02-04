--account.lua

local store_mgr = quanta.get("store_mgr")

local Account = class()
local prop = property(Account)
prop:reader("params", {})           --params
prop:reader("user_id", 0)           --user_id
prop:reader("channel","")           --channel
prop:reader("open_id", "")          --open_id
prop:reader("device_id", 0)         --device_id
prop:reader("create_time", 0)       --create_time
prop:accessor("reload_token", 0)    --reload_token

local dprop = db_property(Account, "account", true)
dprop:store_value("lobby", 0)       --lobby
dprop:store_values("roles", {})     --roles

function Account:__init(open_id)
    self.open_id = open_id
end

function Account:load()
    return store_mgr:load(self, self.open_id, "account")
end

function Account:on_db_account_load(data)
    if data.open_id then
        self.lobby = data.lobby
        self.roles = data.roles
        self.params = data.params
        self.user_id = data.user_id
        self.device_id = data.device_id
        self.create_time = data.create_time
        self.channel = data.channel or "default"
        return true
    end
    return false
end

function Account:update_nick(role_id, name)
    local role = self.roles[role_id]
    if role then
        role.name = name
        self:save_roles_field(role_id, role)
    end
end

function Account:update_custom(role_id, custom)
    local role = self.roles[role_id]
    if role then
        role.custom = custom
        self:save_roles_field(role_id, role)
    end
end

return Account
