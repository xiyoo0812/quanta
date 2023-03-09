--db_property.lua
--[[提供对象DB属性机制
示例:
local AAcomponent = mixin()
local prop = db_property(AAcomponent, "packet")
prop:store_value("capacity", 2)     --capacity
prop:store_objects("packets", {})   --packets

function AAcomponent:__init()
    self:init_player_db(self.id, function()
        --xxx
    end)
end

local SPlayer = class(nil, AAC)
local prop = db_property(SPlayer, "player")
prop:store_value("level", 2)            --level
prop:store_value("name", "")            --name
prop:store_values("games", {})          --games

function SPlayer:__init()
    self:init_player_db(self.id, function()
        --xxx
    end)
end
--]]

local sformat   = string.format

local event_mgr = quanta.get("event_mgr")

local function on_db_sheet_load(object, sheet, data)
    local f_db_sheet_load = object["on_db_" .. sheet .. "_load"]
    if f_db_sheet_load then
        if f_db_sheet_load(object, data) then
            object["load_" .. sheet .. "_success"] = true
            return true, data
        end
        return false
    end
    return true, data
end

local function on_db_prop_update(object, primary_id, sheet, db_key, value, force)
    if force or object["load_" .. sheet .. "_success"] then
        local result = event_mgr:notify_listener("on_db_prop_update", primary_id, sheet, db_key, value)
        if result[1] then
            return result[2]
        end
    end
    return false
end

local function on_db_prop_remove(primary_id, sheet, db_key)
    local result =  event_mgr:notify_listener("on_db_prop_remove", primary_id, sheet, db_key)
    if result[1] then
        return result[2]
    end
    return false
end

local function db_prop_op_sheet_key(class, sheet, sheetkey, sheetprimary)
    class["load_" .. sheet .. "_db"] = function(self, primary_key, f_db_load)
        self[sheetkey] = sheet
        self[sheetprimary] = primary_key
        local success, data = f_db_load()
        if success then
            return on_db_sheet_load(self, sheet, data)
        end
        return success
    end
    class["flush_" .. sheet] = function(self)
        return on_db_prop_update(self, self[sheetprimary], sheet, self[sheetkey], self:pack2db(), true)
    end
end

local function db_prop_op_value(class, sheet, sheetkey, sheetroot, sheetprimary, name, default)
    class.__props[name] = { default }
    class["get_" .. name] = function(self)
        return self[name]
    end
    class["set_" .. name] = function(self, value, force)
        if self[name] ~= value then
            self[name] = value
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = sformat("%s.%s", sheet_key, name)
                return on_db_prop_update(root, root[sheetprimary], sheet, db_key, value, force)
            end
        end
        return true
    end
end

local function db_prop_op_values(class, sheet, sheetkey, sheetroot, sheetprimary, name, default)
    class.__props[name] = { default or {} }
    class["get_" .. name] = function(self, key)
        if key then
            return self[name][key]
        end
        return self[name]
    end
    class["set_" .. name] = function(self, value, force)
        if self[name] ~= value then
            self[name] = value
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = sformat("%s.%s", sheet_key, name)
                return on_db_prop_update(root, root[sheetprimary], sheet, db_key, value, force)
            end
        end
        return true
    end
    local set_func_name = "set_" .. name .. "_field"
    local del_func_name = "del_" .. name .. "_field"
    class[set_func_name] = function(self, key, value, force)
        if not value then
            return class[del_func_name](self, key)
        end
        if self[name][key] ~= value then
            self[name][key] = value
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = sformat("%s.%s.%s", sheet_key, name, key)
                return on_db_prop_update(root, root[sheetprimary], sheet, db_key, value, force)
            end
        end
        return true
    end
    class[del_func_name] = function(self, key)
        if self[name][key] then
            self[name][key] = nil
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = sformat("%s.%s.%s", sheet_key, name, key)
                return on_db_prop_remove(root[sheetprimary], sheet, db_key)
            end
        end
        return true
    end
end

local function db_prop_op_objects(class, sheet, sheetkey, sheetroot, sheetprimary, name, default)
    class.__props[name] = { default or {} }
    class["get_" .. name] = function(self, key)
        if key then
            return self[name][key]
        end
        return self[name]
    end
    local set_func_name = "set_" .. name .. "_elem"
    local del_func_name = "del_" .. name .. "_elem"
    class[set_func_name] = function(self, key, value, force)
        if not value then
            return class[del_func_name](self, key)
        end
        if self[name][key] ~= value then
            self[name][key] = value
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = sformat("%s.%s.%s", sheet_key, name, key)
                value[sheetkey] = db_key
                value[sheetroot] = root
                return on_db_prop_update(root, root[sheetprimary], sheet, db_key, value:pack2db(), force)
            end
        end
        return true
    end
    class[del_func_name] = function(self, key)
        local value = self[name][key]
        if value then
            self[name][key] = nil
            value[sheetroot] = nil
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = sformat("%s.%s.%s", sheet_key, name, key)
                return on_db_prop_remove(root[sheetprimary], sheet, db_key)
            end
        end
        return true
    end
end

local property_accessor_value = function(self, name, default)
    db_prop_op_value(self.__class, self.__sheet, self.__key, self.__root, self.__primary, name, default)
end

local property_accessor_values = function(self, name, default)
    db_prop_op_values(self.__class, self.__sheet, self.__key, self.__root, self.__primary, name, default)
end

local property_accessor_objects = function(self, name, default)
    db_prop_op_objects(self.__class, self.__sheet, self.__key, self.__root, self.__primary, name, default)
end

function db_property(class, sheet)
    local prop = {
        __class = class,
        __sheet = sheet,
        __key = "__key_" .. sheet,
        __root = "__root_" .. sheet,
        __primary = "__primary_" .. sheet,
        store_value = property_accessor_value,
        store_values = property_accessor_values,
        store_objects = property_accessor_objects
    }
    db_prop_op_sheet_key(prop.__class, sheet, prop.__key, prop.__primary)
    return prop
end

