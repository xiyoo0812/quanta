--class.lua
local type          = type
local load          = load
local pcall         = pcall
local pairs         = pairs
local ipairs        = ipairs
local rawget        = rawget
local rawset        = rawset
local tostring      = tostring
local ssub          = string.sub
local sformat       = string.format
local sgmatch       = string.gmatch
local dgetinfo      = debug.getinfo
local tab_copy      = table.copy
local deep_copy     = table.deepcopy
local getmetatable  = getmetatable
local setmetatable  = setmetatable
local ogetenv       = os.getenv

--类模板
local class_tpls = _ENV.__classes or {}

local function class_raw_call(method, class, obj, ...)
    local class_base_func = rawget(class.__vtbl, method)
    if class_base_func then
        class_base_func(obj, ...)
    end
end

local function class_mixin_call(method, class, obj, ...)
    for _, mixin in ipairs(class.__mixins) do
        local mixin_base_func = rawget(mixin.__methods, method)
        if mixin_base_func then
            mixin_base_func(obj, ...)
        end
    end
end

local function object_reload(class, obj)
    local super = class.__super
    if super then
        object_reload(super, obj)
    end
    class_mixin_call("__reload", class, obj)
    class_raw_call("__reload", class, obj)
end

local function object_init(class, obj, ...)
    local super = class.__super
    if super then
        object_init(super, obj, ...)
    end
    class_raw_call("__init", class, obj, ...)
    class_mixin_call("__init", class, obj, ...)
    return obj
end

local function object_release(class, obj, ...)
    class_mixin_call("__release", class, obj, ...)
    class_raw_call("__release", class, obj, ...)
    local super = class.__super
    if super then
        object_release(super, obj, ...)
    end
end

local function object_defer(class, obj, ...)
    class_mixin_call("__defer", class, obj, ...)
    class_raw_call("__defer", class, obj, ...)
    local super = class.__super
    if super then
        object_defer(super, obj, ...)
    end
end

local function object_props(class, obj)
    for name, args in pairs(class.__props) do
        local arg, typ = args[1], args[2]
        if arg then
            obj[name] = (typ ~= "table") and arg or deep_copy(arg)
        end
    end
end

local function object_tostring(obj)
    if type(obj.tostring) == "function" then
        return obj:tostring()
    end
    return sformat("%s[%s]", obj.__name, obj.__addr)
end

local function object_constructor(class)
    local obj = {}
    class.__count = class.__count + 1
    object_props(class, obj)
    obj.__addr = ssub(tostring(obj), 8)
    setmetatable(obj, class.__vtbl)
    return obj
end

local function object_super(obj)
    return obj.__super
end

local function object_source(obj)
    return obj.__source
end

local function object_address(obj)
    return obj.__addr
end

local function mt_class_new(class, ...)
    if rawget(class, "__singleton") then
        local obj = rawget(class, "__inst")
        if obj then
            object_reload(class, obj)
        else
            obj = object_constructor(class)
            rawset(class, "__inst", obj)
            rawset(class, "inst", function()
                return obj
            end)
            object_init(class, obj, ...)
        end
        return obj
    else
        local obj = object_constructor(class)
        return object_init(class, obj, ...)
    end
end

local function mt_class_index(class, field)
    return class.__vtbl[field]
end

local function mt_class_newindex(class, field, value)
    if rawget(class.__vtbl, field) then
        if ssub(field, 1, 2) ~= "__" and not ogetenv("HOTFIX") then
            warn(sformat("the class %s: %s has repeat defined.", class.__name, field))
        end
    elseif field == "__init_static" then
        value()
    end
    class.__vtbl[field] = value
end

local function mt_object_release(obj)
    local class = obj.__class
    class.__count = class.__count - 1
    object_release(obj.__class, obj)
end

local function mt_object_defer(obj)
    object_defer(obj.__class, obj)
end

local classMT = {
    __call = mt_class_new,
    __index = mt_class_index,
    __newindex = mt_class_newindex
}

local function class_constructor(class, super, ...)
    local info = dgetinfo(2, "S")
    local source = info.source
    local class_tpl = class_tpls[source]
    local class_name = sformat("class:%s", sgmatch(source, ".+[/\\](.+).lua")())
    if not class_tpl then
        local vtbl = {
            __class = class,
            __super = super,
            __source = source,
            __name = class_name,
            __gc = mt_object_release,
            __close = mt_object_defer,
            __tostring = object_tostring,
            super = object_super,
            source = object_source,
            address = object_address
        }
        vtbl.__index = vtbl
        class.__count = 0
        class.__props = {}
        class.__mixins = {}
        class.__vtbl = vtbl
        if super then
            tab_copy(super.__props, class.__props)
            setmetatable(vtbl, { __index = super })
        end
        class_tpl = setmetatable(class, classMT)
        implemented(class, ...)
        class_tpls[source] = class_tpl
    end
    return class_tpl
end

function class(super, ...)
    return class_constructor({}, super, ...)
end

function singleton(super, ...)
    return class_constructor({__singleton = true}, super, ...)
end

function super(value)
    return value.__super
end

function is_class(class)
    return classMT == getmetatable(class)
end

function classof(obj)
    return obj.__class
end

function conv_class(name)
    local runtime = sformat("local obj = %s() return obj", name)
    local ok, obj = pcall(load(runtime))
    if ok then
        return obj
    end
end

function class_review()
    local review = {}
    for _, class in pairs(class_tpls) do
        if class.__count > 0 then
            review[class.__name] = class.__count
        end
    end
    return review
end

_ENV.__classes = class_tpls
