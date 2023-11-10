--db_property.lua
--[[提供对象DB属性机制
--]]
local tconcat   = table.concat

local event_mgr = quanta.get("event_mgr")

local function fmt_sheet_key(root, ...)
    if #root > 0 then
        return tconcat({ root, ... }, ".")
    end
    return tconcat({ ... }, ".")
end

local function on_db_prop_update(primary_id, sheet, db_key, value)
    event_mgr:notify_listener("on_db_prop_update", primary_id, sheet, db_key, value)
end

local function on_db_prop_remove(primary_id, sheet, db_key)
    event_mgr:notify_listener("on_db_prop_remove", primary_id, sheet, db_key)
end

local function db_prop_op_sheet_key(class, sheet, sheetkey, sheetroot, sheetprimary)
    class["flush_" .. sheet .. "_db"] = function(self)
        on_db_prop_update(self[sheetroot][sheetprimary], sheet, self[sheetkey], self:pack2db())
    end
end

local function db_root_prop_op_sheet_key(class, sheet, sheetkey, sheetprimary)
    class["load_" .. sheet .. "_db"] = function(self, primary_key, data)
        self[sheetkey] = ""
        self[sheetprimary] = primary_key
        self["on_db_" .. sheet .. "_load"](self, data)
        self["__" .. sheet .. "_loaded"] = true
    end
    class["init_" .. sheet .. "_db"] = function(self, values)
        on_db_prop_update(self[sheetprimary], sheet, self[sheetkey], values)
    end
    class["is_" .. sheet .. "_loaded"] = function(self)
        return self["__" .. sheet .. "_loaded"]
    end
end

local function db_prop_op_value(class, sheet, sheetkey, sheetroot, sheetprimary, name, default)
    class.__props[name] = { default }
    class["get_" .. name] = function(self)
        return self[name]
    end
    class["set_" .. name] = function(self, value)
        if self[name] ~= value or type(value) == "table" then
            self[name] = value
        end
    end
    class["save_" .. name] = function(self, value)
        if self[name] ~= value or type(value) == "table" then
            self[name] = value
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = fmt_sheet_key(sheet_key, name)
                on_db_prop_update(root[sheetprimary], sheet, db_key, value)
            end
        end
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
    class["set_" .. name] = function(self, values)
        if self[name] ~= values or type(values) == "table" then
            self[name] = values
        end
    end
    class["save_" .. name] = function(self, values)
        if self[name] ~= values or type(values) == "table" then
            self[name] = values
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = fmt_sheet_key(sheet_key, name)
                on_db_prop_update(root[sheetprimary], sheet, db_key, values)
            end
        end
    end
    local set_func_name = "set_" .. name .. "_field"
    local del_func_name = "del_" .. name .. "_field"
    local save_func_name = "save_" .. name .. "_field"
    class[set_func_name] = function(self, key, value)
        if self[name][key] ~= value or type(value) == "table" then
            self[name][key] = value
        end
    end
    class[save_func_name] = function(self, key, value)
        if not value then
            return class[del_func_name](self, key)
        end
        if self[name][key] ~= value or type(value) == "table" then
            self[name][key] = value
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = fmt_sheet_key(sheet_key, name, key)
                on_db_prop_update(root[sheetprimary], sheet, db_key, value)
            end
        end
    end
    class[del_func_name] = function(self, key)
        if self[name][key] then
            self[name][key] = nil
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = fmt_sheet_key(sheet_key, name, key)
                on_db_prop_remove(root[sheetprimary], sheet, db_key)
            end
        end
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
    local save_func_name = "save_" .. name .. "_elem"
    class[set_func_name] = function(self, key, value)
        self[name][key] = value
        local sheet_key = self[sheetkey]
        if sheet_key then
            value[sheetroot] = self[sheetroot] or self
            value[sheetkey] = fmt_sheet_key(sheet_key, name, key)
        end
    end
    class[save_func_name] = function(self, key, value)
        if not value then
            return class[del_func_name](self, key)
        end
        self[name][key] = value
        local sheet_key = self[sheetkey]
        if sheet_key then
            local root = self[sheetroot] or self
            local db_key = fmt_sheet_key(sheet_key, name, key)
            value[sheetkey] = db_key
            value[sheetroot] = root
            on_db_prop_update(root[sheetprimary], sheet, db_key, value:pack2db())
        end
    end
    class[del_func_name] = function(self, key)
        local value = self[name][key]
        if value then
            self[name][key] = nil
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = fmt_sheet_key(sheet_key, name, key)
                on_db_prop_remove(root[sheetprimary], sheet, db_key)
                value[sheetroot] = nil
                value[sheetkey] = nil
            end
        end
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

function db_property(class, sheet, root)
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
    if root then
        db_root_prop_op_sheet_key(prop.__class, sheet, prop.__key, prop.__primary)
    else
        db_prop_op_sheet_key(prop.__class, sheet, prop.__key, prop.__root, prop.__primary)
    end
    return prop
end
