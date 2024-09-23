--account.lua

local tsize         = qtable.size
local tinsert       = table.insert
local guid_new      = codec.guid_new

local store_mgr     = quanta.get("store_mgr")

local Account = class()
local prop = property(Account)
prop:reader("open_id", "")    --open_id

local store = storage(Account, "account")
store:store_value("token", 0)       --token
store:store_value("lobby", 0)       --lobby
store:store_value("user_id", 0)     --user_id
store:store_value("device_id", 0)   --device_id
store:store_value("create_time", 0) --create_time
store:store_value("channel","")     --channel
store:store_values("params", {})    --params
store:store_values("roles", {})     --roles

function Account:__init(open_id)
    self.open_id = open_id
end

function Account:create(token, device_id, params, channel)
    self.token = token
    self.params = params
    self.device_id = device_id
    self.create_time = quanta.now
    self.channel = channel or "default"
    self.user_id = guid_new(quanta.service, quanta.index)
    self:flush_account_db(true)
    return true
end

function Account:is_newbee()
    return self.create_time == 0
end

function Account:update_params(params)
    for key, value in pairs(params) do
        self:save_params_field(key, value)
    end
end

function Account:get_role(role_id)
    return self.roles[role_id]
end

function Account:get_role_count()
    return tsize(self.roles)
end

function Account:load()
    return store_mgr:load(self, self.open_id, "account")
end

function Account:on_db_account_load(data)
    if data.open_id then
        self:set_token(data.token)
        self:set_lobby(data.lobby)
        self:set_params(data.params)
        self:set_user_id(data.user_id)
        self:set_device_id(data.device_id)
        self:set_create_time(data.create_time)
        self:set_channel(data.channel or "default")
        self:set_roles(data.roles or {})
    end
end

function Account:del_role(role_id)
    local role = self.roles[role_id]
    if role then
        return self:del_roles_field(role_id)
    end
    return false
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
