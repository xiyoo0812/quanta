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

local function on_db_sheet_load(object, sheet, data)
    local f_db_sheet_load = object["on_db_" .. sheet .. "_load"]
    if f_db_sheet_load then
        if f_db_sheet_load(object, data) then
            object["__db_" .. sheet .. "_syncing"] = true
            return true, data
        end
        return false
    end
    return true, data
end

local function on_db_prop_update(object, primary_id, sheet, db_key, value, flush)
    if flush or object["__db_" .. sheet .. "_syncing"] then
        local result = event_mgr:notify_listener("on_db_prop_update", primary_id, sheet, db_key, value, flush)
        if result[1] then
            return result[2]
        end
    end
    return false
end

local function on_db_prop_remove(primary_id, sheet, db_key, flush)
    local result =  event_mgr:notify_listener("on_db_prop_remove", primary_id, sheet, db_key, flush)
    if result[1] then
        return result[2]
    end
    return false
end

local function db_prop_op_sheet_key(class, sheet, sheetkey, sheetprimary)
    class["load_" .. sheet .. "_db"] = function(self, primary_key, f_db_load)
        self[sheetkey] = ""
        self[sheetprimary] = primary_key
        local success, data = f_db_load()
        if success then
            return on_db_sheet_load(self, sheet, data)
        end
        return success
    end
    class["flush_" .. sheet] = function(self, value)
        return on_db_prop_update(self, self[sheetprimary], sheet, self[sheetkey], value, true)
    end
    local sheet_status_name = "__db_" .. sheet .. "_syncing"
    class["pause_" .. sheet .. "_sync"] = function(self)
        if self[sheet_status_name] ~= nil then
            self[sheet_status_name] = false
        end
    end
    class["continue_" .. sheet .. "_sync"] = function(self)
        if self[sheet_status_name] ~= nil then
            self[sheet_status_name] = true
        end
    end
    class["is_" .. sheet .. "_loaded"] = function(self)
        return self[sheet_status_name]
    end
end

local function db_prop_op_value(class, sheet, sheetkey, sheetroot, sheetprimary, name, default)
    class.__props[name] = { default }
    class["get_" .. name] = function(self)
        return self[name]
    end
    class["set_" .. name] = function(self, value, flush)
        if self[name] ~= value or type(value) == "table" then
            self[name] = value
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = fmt_sheet_key(sheet_key, name)
                return on_db_prop_update(root, root[sheetprimary], sheet, db_key, value, flush)
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
    class["set_" .. name] = function(self, value, flush)
        self[name] = value
        local sheet_key = self[sheetkey]
        if sheet_key then
            local root = self[sheetroot] or self
            local db_key = fmt_sheet_key(sheet_key, name)
            return on_db_prop_update(root, root[sheetprimary], sheet, db_key, value, flush)
        end
        return true
    end
    local set_func_name = "set_" .. name .. "_field"
    local del_func_name = "del_" .. name .. "_field"
    class[set_func_name] = function(self, key, value, flush)
        if not value then
            return class[del_func_name](self, key)
        end
        if self[name][key] ~= value or type(value) == "table" then
            self[name][key] = value
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = fmt_sheet_key(sheet_key, name, key)
                return on_db_prop_update(root, root[sheetprimary], sheet, db_key, value, flush)
            end
        end
        return true
    end
    class[del_func_name] = function(self, key, flush)
        if self[name][key] then
            self[name][key] = nil
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = fmt_sheet_key(sheet_key, name, key)
                return on_db_prop_remove(root[sheetprimary], sheet, db_key, flush)
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
    class[set_func_name] = function(self, key, value, flush)
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
            return on_db_prop_update(root, root[sheetprimary], sheet, db_key, value:pack2db(), flush)
        end
        return true
    end
    class[del_func_name] = function(self, key, flush)
        local value = self[name][key]
        if value then
            self[name][key] = nil
            value[sheetroot] = nil
            local sheet_key = self[sheetkey]
            if sheet_key then
                local root = self[sheetroot] or self
                local db_key = fmt_sheet_key(sheet_key, name, key)
                return on_db_prop_remove(root[sheetprimary], sheet, db_key, flush)
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
        db_prop_op_sheet_key(prop.__class, sheet, prop.__key, prop.__primary)
    end
    return prop
end

