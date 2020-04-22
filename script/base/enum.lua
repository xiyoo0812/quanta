--enum.lua
--[[提供枚举机制
示例:
    local enum = require(enum)
    用法1：
    local TEST1 = enum("TEST1", 0, "ONE", "THREE", "TWO")
    print(TEST1.TWO)
    用法2：
    local TEST2 = enum("TEST2", 1, "ONE", "THREE", "TWO")
    TEST2.FOUR = TEST2()
    print(TEST2.TWO, TEST2.FOUR)
    用法3：
    local TEST3 = enum("TEST3", 2)
    TEST3("ONE")
    TEST3("TWO")
    TEST3("FOUR", 4)
    local five = TEST3("FIVE")
    print(TEST3.TWO, TEST3.FOUR, TEST3.FIVE, five)
--]]
local ipairs        = ipairs
local rawget        = rawget
local rawset        = rawset
local setmetatable  = setmetatable
local dgetinfo      = debug.getinfo
local sformat       = string.format
local serialize     = logger.serialize
local log_warn      = logger.warn

local enums         = {}

local function enum_tostring(eo)
    return sformat("enum:%s(max:%s, list:%s)", eo.__name, eo.__vmax, serialize(eo.__vlist))
end

local function enum_new(enum, field, value)
    value = value or enum.__vmax
    if field then
        enum.__vlist[field] = value
        if value >= enum.__vmax then
            enum.__vmax = value + 1
        end
    end
    return value
end

local function enum_index(enum, field)
    return enum.__vlist[field]
end

local function enum_newindex(enum, field, value)
    enum.__vlist[field] = value
    if value >= enum.__vmax then
        enum.__vmax = value + 1
    end
end

local function enum_init(enum, base, ...)
    enum.__vlist = {}
    enum.__vmax = base
    local values = { ... }
    for _, key in ipairs(values) do
        enum.__vlist[key] = enum.__vmax
        enum.__vmax = enum.__vmax + 1
    end
end

local enumMT = {
    __call = enum_new,
    __index = enum_index,
    __newindex = enum_newindex,
    __tostring = enum_tostring,
}

local function enum_list(em)
    local elist = rawget(em, "__list")
    if not elist then
        elist = {}
        rawset(em, "__list", elist)
    end
    return elist
end

local function new(em, name, base, ...)
    local info = dgetinfo(2, "S")
    local moudle = info.short_src
    local lists = enum_list(em)
    local eobj = lists[name]
    if not eobj then
        eobj = {
            __name = name,
            __moudle = moudle,
        }
    else
        if eobj.__moudle ~= moudle then
            log_warn("enum %s redefined! moudle:%s", name, moudle)
        end
    end
    enum_init(eobj, base, ...)
    setmetatable(eobj, enumMT)
    lists[name] = eobj
    return eobj
end

local function index(em, field)
    local lists = enum_list(em)
    return lists[field]
end

local function newindex(em, field, value)
    local lists = enum_list(em)
    lists[field] = value
end

local MT = {
    __call = new,
    __index = index,
    __newindex = newindex
}

return setmetatable(enums, MT)
