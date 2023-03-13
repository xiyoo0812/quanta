--account.lua

local tsize         = qtable.size
local tinsert       = table.insert
local guid_new      = quanta.new_guid

local game_dao      = quanta.get("game_dao")
local login_dao     = quanta.get("login_dao")

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
dprop:store_values("params", {})    --params
dprop:store_values("roles", {})     --roles

function Account:__init(open_id)
    self.open_id = open_id
end

function Account:create(token, device_id, params)
    self.token = token
    self.params = params
    self.device_id = device_id
    self.create_time = quanta.now
    self.user_id = guid_new(quanta.service, quanta.index)
    return self:flush_account(self:pack2db())
end

function Account:is_newbee()
    return self.create_time == 0
end

function Account:get_role(role_id)
    return self.roles[role_id]
end

function Account:get_role_count()
    return tsize(self.roles)
end

function Account:load()
    local function load_account()
        return game_dao:load(self.open_id, "account")
    end
    return self:load_account_db(self.open_id, load_account)
end

function Account:on_db_account_load(data)
    if data and data.account then
        local account_data = data.account
        self.token = account_data.token
        self.lobby = account_data.lobby
        self.params = account_data.params
        self.user_id = account_data.user_id
        self.device_id = account_data.device_id
        self.login_time = account_data.login_time
        self.create_time = account_data.create_time
        self.login_token = account_data.login_token
        self.roles = account_data.roles or {}
    end
    return true
end

function Account:add_role(body)
    local role_id = login_dao:get_autoinc_id(self.open_id)
    if not role_id then
        return
    end
    if self:set_roles_field(role_id, body) then
        login_dao:create_player(role_id, body)
        return role_id, body
    end
end

function Account:del_role(role_id)
    local role = self.roles[role_id]
    if role then
        return self:del_roles_field(role_id)
    end
    return false
end

function Account:pack2db()
    return {
        token = self.token,
        lobby = self.lobby,
        params = self.params,
        user_id = self.user_id,
        device_id = self.device_id,
        create_time = self.create_time,
    }
end

function Account:pack2client()
    local roles = {}
    for role_id, role in pairs(self.roles or {}) do
        tinsert(roles, { role_id = role_id, gender = role.gender, name = role.name })
    end
    return {
        roles = roles,
        error_code = 0,
        user_id = self.user_id,
    }
end

return Account
