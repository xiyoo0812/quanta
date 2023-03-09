--db_account.lua

local tsize         = qtable.size
local tinsert       = table.insert
local guid_new      = quanta.new_guid

local game_dao      = quanta.get("game_dao")
local login_dao     = quanta.get("login_dao")

local DBRole        = import("login/object/db_role.lua")

local DBAccount = class()
local prop = property(DBAccount)
prop:reader("user_id", 0)           --user_id
prop:reader("open_id", "")          --open_id
prop:reader("create_time", 0)       --create_time

local dprop = db_property(DBAccount, "account")
dprop:store_value("token", 0)       --token
dprop:store_value("lobby", 0)       --lobby
dprop:store_value("device_id", 0)   --device_id
dprop:store_value("login_time", 0)  --login_time
dprop:store_value("login_token", 0) --login_token
dprop:store_value("reload_token", 0)--reload_token
dprop:store_values("params", {})    --params
dprop:store_objects("roles", {})    --roles

function DBAccount:__init(open_id)
    self.open_id = open_id
end

function DBAccount:create(token, device_id, params)
    self.token = token
    self.params = params
    self.device_id = device_id
    self.create_time = quanta.now
    self.user_id = guid_new(quanta.service, quanta.index)
    return self:flush_account()
end

function DBAccount:is_newbee()
    return self.create_time == 0
end

function DBAccount:get_role(role_id)
    return self.roles[role_id]
end

function DBAccount:get_role_count()
    return tsize(self.roles)
end

function DBAccount:load()
    local function load_account()
        return game_dao:load(self.open_id, "account")
    end
    return self:load_account_db(self.open_id, load_account)
end

function DBAccount:on_db_account_load(data)
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
        self.reload_token = account_data.reload_token
        for role_id, role_data in pairs(account_data.roles or {}) do
            local role = DBRole(role_id, role_data)
            self:set_roles_elem(role_id, role)
        end
    end
    return true
end

function DBAccount:add_role(data)
    local role_id = login_dao:get_autoinc_id(self.open_id)
    if not role_id then
        return
    end
    local role = DBRole(role_id, data)
    if self:set_roles_elem(role_id, role) then
        login_dao:create_player(role_id, data)
        return role
    end
end

function DBAccount:del_role(role_id)
    local role = self.roles[role_id]
    if role then
        return self:del_roles_elem(role_id)
    end
    return false
end

function DBAccount:pack2db()
    return {
        token = self.token,
        lobby = self.lobby,
        params = self.params,
        user_id = self.user_id,
        device_id = self.device_id,
        create_time = self.create_time,
    }
end

function DBAccount:pack2client()
    local roles = {}
    for _, role in pairs(self.roles) do
        tinsert(roles, role:pack2client())
    end
    return {
        roles = roles,
        error_code = 0,
        user_id = self.user_id,
    }
end

return DBAccount
