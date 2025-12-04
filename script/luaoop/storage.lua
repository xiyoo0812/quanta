--storange.lua
--[[提供对象存储机制
示例:
    local Object = class()
    store = storage(Object, "player")
    store:store_value("id", 0)
    store:store_values("ids", {})
    store:store_object("obj", nil)
    store:store_objects("objs", {})
--]]

local type      = type
local tcopy     = table.copy

local NULL      = "null"

local function clone_arg(arg)
    if type(arg) ~= "table" then
        return arg
    end
    return tcopy(arg)
end

local function get_storage_layers(obj, sheet)
    if sheet ~= NULL then
        return obj["__storage_" .. sheet], {}
    end
    return obj.__storage, obj.__layers
end

local function gen_storage_layers(obj, store, par_layers, name, field)
    if store then
        local layers = {}
        for i, value in ipairs(par_layers or {}) do
            layers[i] = value
        end
        layers[#layers + 1] = name
        if field then
            layers[#layers + 1] = field
        end
        obj.__layers = layers
        obj.__storage = store
    end
end

local function update_store_value(obj, sheet, name, value, is_obj)
    local store, layers = get_storage_layers(obj, sheet)
    if store then
        if is_obj then
            store:update_value(layers, name, value and value:serialize())
        else
            store:update_value(layers, name, value)
        end
        return store, layers
    end
end

local function update_store_field(obj, sheet, name, field, value, is_obj)
    local store, layers = get_storage_layers(obj, sheet)
    if store then
        if is_obj then
            store:update_field(layers, name, field, value and value:serialize())
        else
            store:update_field(layers, name, field, value)
        end
        return store, layers
    end
end

local function define_getter(class, name, default)
    class["get_" .. name] = function(self)
        return self[name]
    end
    if type(default) == "boolean" then
        class["is_" .. name] = class["get_" .. name]
    end
end

local function define_setter(class, sheet, name, default, is_obj)
    class["set_" .. name] = function(self, value, memory)
        if self[name] ~= value then
            if value == nil then
                value = clone_arg(default)
            end
            self[name] = value
            if memory then return end
            if is_obj and value then
                local store, layers = get_storage_layers(self, sheet)
                if store then
                    gen_storage_layers(value, store, layers, name)
                end
            end
        end
    end
end

local function define_saver(class, sheet, name, is_obj)
    class["save_" .. name] = function(self, value)
        if self[name] ~= value or type(value) == "table" then
            self[name] = value
            local store, layers = update_store_value(self, sheet, name, value, is_obj)
            if store and is_obj and value then
                gen_storage_layers(value, store, layers, name)
            end
        end
    end
end

local function define_field_getter(class, name, suffix)
    class["get_" .. name .. suffix] = function(self, key)
        return self[name][key]
    end
end

local function define_field_setter(class, sheet, name, suffix, is_obj)
    class["set_" .. name .. suffix] = function(self, key, value, memory)
        if self[name][key] ~= value then
            self[name][key] = value
            if memory then return end
            local store, layers = get_storage_layers(self, sheet)
            if store and is_obj and value then
                gen_storage_layers(value, store, layers, name, key)
            end
        end
    end
end

local function define_field_saver(class, sheet, name, suffix, is_obj)
    class["save_" .. name .. suffix] = function(self, key, value)
        if self[name][key] ~= value or type(value) == "table" then
            self[name][key] = value
            local store, layers = update_store_field(self, sheet, name, key, value, is_obj)
            if store and is_obj and value then
                gen_storage_layers(value, store, layers, name, key)
            end
        end
    end
end

local function define_field_deleter(class, sheet, name, suffix, is_obj)
    class["del_" .. name .. suffix] = function(self, key)
        local value = self[name][key]
        if value then
            self[name][key] = nil
            local store = update_store_field(self, sheet, name, key, nil, is_obj)
            if store and is_obj then
                value.__storage = nil
                value.__layers = nil
            end
        end
    end
end

local function define_field_flusher(class, sheet, name, suffix, is_obj)
    class["flush_" .. name .. suffix] = function(self, key)
        local value = self[name][key]
        if value then
            update_store_field(self, sheet, name, key, value, is_obj)
        end
    end
end

local function prop_store_base(class, sheet, name, default, kind)
    class.__props[name] = { default, kind }
    local sheet_key = "__sheet_" .. sheet
    if class[sheet_key] then
        class[sheet_key][name] = class.__props[name]
    else
        class[sheet_key] = { [name] = class.__props[name] }
    end
end

local function prop_store_delegate(class, sheet, name, default, kind)
    define_getter(class, name, default)
    define_saver(class, sheet, name, kind == "O" or kind == "H")
    define_setter(class, sheet, name, default, kind == "O" or kind == "H")
    prop_store_base(class, sheet, name, default, kind)
    if kind == "S" then
        define_field_getter(class, name, "_field")
        define_field_saver(class, sheet, name, "_field")
        define_field_setter(class, sheet, name, "_field")
        define_field_deleter(class, sheet, name, "_field")
        define_field_flusher(class, sheet, name, "_field")
    end
    if kind == "H" then
        define_field_getter(class, name, "_elem", true)
        define_field_saver(class, sheet, name, "_elem", true)
        define_field_setter(class, sheet, name, "_elem", true)
        define_field_deleter(class, sheet, name, "_elem", true)
        define_field_flusher(class, sheet, name, "_elem", true)
    end
end

local storage_prop_value = function(store, name, default)
    prop_store_delegate(store.__class, store.__sheet, name, default, "V")
end
local storage_prop_values = function(store, name, default)
    prop_store_delegate(store.__class, store.__sheet, name, default, "S")
end
local storage_prop_object = function(store, name, default)
    prop_store_delegate(store.__class, store.__sheet, name, default, "O")
end
local storage_prop_objects = function(store, name, default)
    prop_store_delegate(store.__class, store.__sheet, name, default, "H")
end

local storage_serialize = function(class, sheet_key)
    return function(obj)
        local value = {}
        for key, info in pairs(class[sheet_key] or {}) do
            if info[2] == "V" or info[2] == "S" then
                value[key] = obj[key]
            elseif info[2] == "H" then
                value[key] = {}
                for idx, sobj in pairs(obj[key]) do
                    value[key][idx] = sobj:serialize()
                end
            elseif info[2] == "O" then
                value[key] = obj[key]:serialize()
            end
        end
        return value
    end
end

local storage_sheet_init = function(class, sheet)
    local sheet_key = "__sheet_" .. sheet
    local storage_key = "__storage_" .. sheet
    class["load_" .. sheet .. "_db"] = function(self, store, data)
        self[storage_key] = store
        self["__" .. sheet .. "_loaded"] = true
        self["on_db_" .. sheet .. "_load"](self, data)
    end
    class["flush_" .. sheet .. "_db"] = function(self, timely)
        self[storage_key]:flush(self, timely)
    end
    class["is_" .. sheet .. "_loaded"] = function(self)
        return self["__" .. sheet .. "_loaded"]
    end
    class["delete_" .. sheet .. "_db"] = function(self, mgr)
        local store = self[storage_key]
        self[storage_key] = nil
        mgr:clean_store(store)
        store:delete()
    end
    --生成序列化接口
    class["serialize_" .. sheet] = storage_serialize(class, sheet_key)
end

function storage(class, sheet)
    local store = {
        __class = class,
        __sheet = sheet or NULL,
        store_value = storage_prop_value,
        store_values = storage_prop_values,
        store_object = storage_prop_object,
        store_objects = storage_prop_objects,
    }
    if sheet then
        storage_sheet_init(class, sheet)
        return store
    end
    if is_class(class) then
        local sheet_key = "__sheet_" .. store.__sheet
        class["serialize"] = storage_serialize(class, sheet_key)
    end
    return store
end
