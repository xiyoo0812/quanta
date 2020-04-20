--[[property.lua
    local Object = class()
    prop = property(Object)
    prop:reader("id", 0)
    prop:accessor("name", "")
--]]
local type      = type

local ACCESSOR  = 1
local WRITER    = 2
local READER    = 3

local function prop_accessor(prop, class, name, default, mode, cb)
    class.__default[name] = { default }
    if mode <= WRITER then
        class["set_" .. name] = function(self, value)
            if self[name] == nil or self[name] ~= value then
                self[name] = value
                if cb then
                    cb(self, name, value)
                end
            end
        end
        mode = mode + 2
    end
    if mode <= READER then
        class["get_" .. name] = function(self)
            if self[name] == nil then
                return default
            end
            return self[name]
        end
        if type(default) == "boolean" then
            class["is_" .. name] = class["get_" .. name]
        end
    end
end

local property_reader = function(self, name, default)
    prop_accessor(self, self.__class, name, default, READER)
end
local property_writer = function(self, name, default, cb)
    prop_accessor(self, self.__class, name, default, WRITER, cb)
end
local property_accessor = function(self, name, default, cb)
    prop_accessor(self, self.__class, name, default, ACCESSOR, cb)
end

function property(class)
    local prop = {
        __class = class,
        reader = property_reader,
        writer = property_writer,
        accessor = property_accessor,
    }
    return prop
end

