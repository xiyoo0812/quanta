--db_property.lua
--[[提供对象DB属性机制
--]]
local tcopy     = qtable.copy
local tpush     = qtable.push

local function build_sheet_keys(parentkeys, ...)
    local newkeys = tcopy(parentkeys)
    return tpush(newkeys, ...)
end

local function db_prop_op_sheet_key(class, sheet, sheetkey)
    local storekey = "__" .. sheet .. "_store"
    class["load_" .. sheet .. "_db"] = function(self, store, data)
        self[sheetkey] = {}
        self[storekey] = store
        self["__" .. sheet .. "_loaded"] = true
        self["on_db_" .. sheet .. "_load"](self, data)
    end
    class["flush_" .. sheet .. "_db"] = function(self)
        self[storekey]:update(self["serialize_" .. sheet](self))
    end
    class["is_" .. sheet .. "_loaded"] = function(self)
        return self["__" .. sheet .. "_flushing"]
    end
end

local function db_prop_op_value(class, sheet, sheetkey, sheetroot, name, default)
    class.__props[name] = { default }
    class["get_" .. name] = function(self)
        return self[name]
    end
    local storekey = "__" .. sheet .. "_store"
    class["set_" .. name] = function(self, value)
        if self[name] ~= value or type(value) == "table" then
            self[name] = value
        end
    end
    class["save_" .. name] = function(self, value)
        if self[name] ~= value or type(value) == "table" then
            self[name] = value
            local sheetkeys = self[sheetkey]
            if sheetkeys then
                local root = self[sheetroot] or self
                root[storekey]:update_value(sheetkeys, name, value)
            end
        end
    end
end

local function db_prop_op_values(class, sheet, sheetkey, sheetroot, name, default)
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
    local storekey = "__" .. sheet .. "_store"
    class["save_" .. name] = function(self, values)
        if self[name] ~= values or type(values) == "table" then
            self[name] = values
            local sheetkeys = self[sheetkey]
            if sheetkeys then
                local root = self[sheetroot] or self
                root[storekey]:update_value(sheetkeys, name, values)
            end
        end
    end
    class["set_" .. name .. "_field"] = function(self, key, value)
        if self[name][key] ~= value or type(value) == "table" then
            self[name][key] = value
        end
    end
    class["save_" .. name .. "_field"] = function(self, key, value)
        if self[name][key] ~= value or type(value) == "table" then
            self[name][key] = value
            local sheetkeys = self[sheetkey]
            if sheetkeys then
                local root = self[sheetroot] or self
                root[storekey]:update_field(sheetkeys, name, key, value)
            end
        end
    end
    class["del_" .. name .. "_field"] = function(self, key)
        if self[name][key] then
            self[name][key] = nil
            local sheetkeys = self[sheetkey]
            if sheetkeys then
                local root = self[sheetroot] or self
                root[storekey]:update_field(sheetkeys, name, key)
            end
        end
    end
end

local function db_prop_op_objects(class, sheet, sheetkey, sheetroot, name, default)
    class.__props[name] = { default or {} }
    class["get_" .. name] = function(self, key)
        if key then
            return self[name][key]
        end
        return self[name]
    end
    local storekey = "__" .. sheet .. "_store"
    class["set_" .. name .. "_elem"] = function(self, key, value)
        self[name][key] = value
        local sheetkeys = self[sheetkey]
        if sheetkeys then
            local root = self[sheetroot] or self
            value[sheetroot] = root
            value[sheetkey] = build_sheet_keys(sheetkeys, name, key)
            return sheetkeys, self[sheetroot] or self
        end
    end
    class["save_" .. name .. "_elem"] = function(self, key, value)
        self[name][key] = value
        local sheetkeys = self[sheetkey]
        if sheetkeys then
            local root = self[sheetroot] or self
            value[sheetroot] = root
            value[sheetkey] = build_sheet_keys(sheetkeys, name, key)
            root[storekey]:update_field(sheetkeys, name, key, value:pack2db())
        end
    end
    class["del_" .. name .. "_elem"] = function(self, key)
        local value = self[name][key]
        if value then
            self[name][key] = nil
            local sheetkeys = self[sheetkey]
            if sheetkeys then
                local root = self[sheetroot] or self
                root[storekey]:update_field(sheetkeys, name, key)
                value[sheetroot] = nil
                value[sheetkey] = nil
            end
        end
    end
end

local property_accessor_value = function(prop, name, default)
    prop.__reflect[name] = true
    db_prop_op_value(prop.__class, prop.__sheet, prop.__key, prop.__root, name, default)
end

local property_accessor_values = function(prop, name, default)
    prop.__reflect[name] = true
    db_prop_op_values(prop.__class, prop.__sheet, prop.__key, prop.__root, name, default)
end

local property_accessor_objects = function(prop, name, default)
    prop.__reflect[name] = false
    db_prop_op_objects(prop.__class, prop.__sheet, prop.__key, prop.__root, name, default)
end

function db_property(class, sheet, root)
    local prop = {
        __class = class,
        __sheet = sheet,
        __key = "__key_" .. sheet,
        __root = "__root_" .. sheet,
        store_value = property_accessor_value,
        store_values = property_accessor_values,
        store_objects = property_accessor_objects,
    }
    prop.__reflect = {}
    db_prop_op_sheet_key(prop.__class, sheet, prop.__key, prop.__root)
    local func_name = root and "serialize_" .. sheet or "serialize"
    class[func_name] = function (obj)
        local value = {}
        if class.__super then
            value = class.__super[func_name](obj)
        end
        for key, leaf in pairs(prop.__reflect) do
            if leaf then
                value[key] = obj[key]
            else
                value[key] = {}
                for idx, sobj in pairs(obj[key]) do
                    value[key][idx] = sobj:serialize()
                end
            end
        end
        return value
    end
    return prop
end
