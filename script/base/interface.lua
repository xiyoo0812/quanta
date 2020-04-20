--interface.lua
--[[提供接口机制
示例:
    Execute = interface(nil, "execute")
    Listener = class(nil, Listener)
备注：
    接口无法实例化，必须依附到class上，接口函数的self都是属主class对象
    接口实例化操作目前相当于类型转换
--]]
local pairs         = pairs
local setmetatable  = setmetatable
local log_warn      = logger.warn
local tinsert       = table.insert
local dgetinfo      = debug.getinfo
local sformat       = string.format

local interface_temples = quanta.interface_temples or {}

local function index(interface, field)
    return interface.__vtbl[field]
end

local function newindex(interface, field, value)
    interface.__vtbl[field] = value
end

--collect==false 表示所有接口都完成
local function invoke(object, method, ...)
    local collect = false
    local class = object.__class
    for _, interface in ipairs(class.__interfaces) do
        if interface[method] then
            if interface[method](object, ...) then
                collect = true
            end
        end
    end

    return collect
end

--代理一个类的所有接口，并检测接口是否实现
function implemented(class, interfaces)
    class.invoke = invoke
    for _, interface in ipairs(interfaces) do
        --属性处理
        for name, value in pairs(interface.__default) do
            if class.__default[name] then
                log_warn("the interface default %s has repeat defined.", name)
            end
            class.__default[name] = value
            local access_prefix = {"is_", "get_", "set_"}
            for _, prefix in pairs(access_prefix) do
                local access_method = prefix .. name
                if interface[access_method] then
                    tinsert(interface.__methods, access_method)
                end
            end
        end
        for _, method in pairs(interface.__methods) do
            if not interface[method] then
                log_warn("the interface method %s hasn't implemented.", method)
                interface[method] = function()
                    log_warn("the interface method %s hasn't implemented.", method)
                end
            end
            if class[method] then
                log_warn("the interface method %s has repeat implemented.", method)
                goto continue
            end
            --接口代理
            class[method] = function(...)
                return interface[method](...)
            end
            :: continue ::
        end
        tinsert(class.__interfaces, interface)
    end
end

local interfaceMT = {
    __index = index,
    __newindex = newindex
}

local function interface_tostring(interface)
    return sformat("interface:%s", interface.__moudle)
end

--接口定义函数
function interface(...)
    local info = dgetinfo(2, "S")
    local moudle = info.short_src
    local interface_tpl = interface_temples[moudle]
    if not interface_tpl then
        local interface = {
            __vtbl = {},
            __default = {},
            __moudle = moudle,
            __methods = { ... },
            __tostring = interface_tostring,
        }
        interface_tpl = setmetatable(interface, interfaceMT)
        interface_temples[moudle] = interface_tpl
    end
    return interface_tpl
end
