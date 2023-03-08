--db_role.lua

local DBRole = class()
local prop = property(DBRole)
prop:reader("id", 0)                --id

local dprop = db_property(DBRole, "account")
dprop:store_value("name", 0)        --name
dprop:store_value("custom", "")     --custom
dprop:store_value("gender", 0)      --gender

function DBRole:__init(id, data)
    self.id = id
    self.name = data.name
    self.gender = data.gender
    self.custom = data.custom
    self.create_time = data.create_time
end

function DBRole:pack2db()
    return {
        name = self.name,
        gender = self.gender,
        custom = self.custom
    }
end

function DBRole:pack2client()
    return {
        name = self.name,
        role_id = self.id,
        gender = self.gender
    }
end


return DBRole
