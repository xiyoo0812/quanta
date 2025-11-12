--mixin.lua
--[[提供混入机制
示例:
    --构造函数混入
    Execute = mixin()
    Listener = class(nil, Listener)
    --委托函数混入
    Robot = class()
    Robot:delegate(Execute)
说明：
    mixin声明的成员自动附加到主类
    mixin声明的函数(除带下划线的私有方法)自动附加到主类
    mixin声明的__init/__release/__defer方法会随主类调用
备注：
    mixin类似多继承，但是继承强调i'am，而mixin强调i'can.
    mixin无法实例化，必须依附到class上，mixin函数的self都是属主class对象
--]]
local pairs         = pairs
local xpcall        = xpcall
local ssub          = string.sub
local dgetinfo      = debug.getinfo
local sformat       = string.format
local sgmatch       = string.gmatch
local tab_copy      = table.copy
local setmetatable  = setmetatable
local dtraceback    = debug.traceback

local mixin_tpls    = _ENV.__mixins or {}

local function mixin_call(mixin, method, ...)
    local mixin_method = mixin[method]
    if mixin_method then
        return mixin_method(...)
    end
end

local function mixin_public_func(mixin, method)
    return function(...)
        return mixin_call(mixin, method, ...)
    end
end

local function mixin_private_func(mixin, method)
    return function(...)
        return mixin_call(mixin, method, ...)
    end
end

local function invoke(class, obj, method, ...)
    local super = class.__super
    if super then
        invoke(super, obj, method, ...)
    end
    for _, mixin in ipairs(class.__mixins) do
        local ok, err = xpcall(mixin_call, dtraceback, mixin, method, obj, ...)
        if not ok then
            error(sformat("mixin: %s invoke '%s' failed: %s.", mixin.__source, method, err))
        end
    end
end

--返回true表示所有接口都完成
local function collect(class, obj, method, ...)
    local super = class.__super
    if super then
        if not collect(super, obj, method, ...) then
            return false
        end
    end
    for _, mixin in ipairs(class.__mixins) do
        local ok, err = xpcall(mixin_call, dtraceback, mixin, method, obj, ...)
        if not ok then
            error(sformat("mixin: %s collect '%s' failed: %s.", mixin.__source, method, err))
            return false
        end
    end
    return true
end

--是否有属性定义
local function has_prop(oopo, name)
    if oopo.__props[name] then
        return true
    end
    return false
end

local function delegate_func(class, mixin, method)
    if ssub(method, 1, 2) == "__" then
        return
    end
    --代理常规接口
    local vtbl = class.__vtbl
    if ssub(method, 1, 1) ~= "_" then
        if vtbl[method] then
            warn(sformat("the mixin method %s has repeat defined.", method))
            return
        end
        --接口代理
        vtbl[method] = mixin_public_func(mixin, method)
        return
    end
    --私有接口代理
    if not class[method] then
        vtbl[method] = mixin_private_func(mixin, method)
    end
end

--代理一个组件
local function delegate_one(class, mixin)
    if mixin.__delegate then
        mixin.__delegate()
    end
    for name, info in pairs(mixin.__props) do
        if has_prop(class, name) then
            warn(sformat("the mixin default %s has repeat defined.", name))
        end
        class.__props[name] = info
    end
    for method in pairs(mixin.__methods) do
        delegate_func(class, mixin, method)
    end
    local cmixins = class.__mixins
    local mowners = mixin.__owners
    cmixins[#cmixins + 1] = mixin
    mowners[#mowners + 1] = class
end

--判定是否已经被代理
local function has_mixin(class, mixin)
    local cmixins = class.__mixins
    for _, omixin in ipairs(cmixins) do
        if omixin == mixin then
            return true
        end
    end
    return false
end

--委托一个mixin给class
local function delegate(class, ...)
    local mixins = { ... }
    for _, mixin in ipairs(mixins) do
        if not has_mixin(class, mixin) then
            delegate_one(class, mixin)
        end
    end
end

--代理一个类的所有接口，并检测接口是否实现
function implemented(class, ...)
    local vtbl = class.__vtbl
    --定义委托接口，在声明后添加委托
    vtbl.delegate = delegate
    --调用所有mixin的接口
    vtbl.invoke = function(object, method, ...)
        invoke(object.__class, object, method, ...)
    end
    --调用所有mixin的接口，并收集结果
    vtbl.collect = function(object, method, ...)
        return collect(object.__class, object, method, ...)
    end
    --委托声明的mixins给class
    delegate(class, ...)
end

local function mt_index(mixin, field)
    return mixin.__methods[field]
end

local function mt_newindex(mixin, field, value)
    mixin.__methods[field] = value
    --新增方法代理
    for _, class in pairs(mixin.__owners) do
        if not class[field] then
            delegate_func(class, mixin, field)
        end
    end
end

local mixinMT = {
    __index = mt_index,
    __newindex = mt_newindex,
}

--接口定义函数
function mixin(super)
    local info = dgetinfo(2, "S")
    local source = info.source
    local mixin_tpl = mixin_tpls[source]
    if not mixin_tpl then
        local mixino = {
            __props = {},
            __owners = {},
            __methods = {},
            __super = super,
            __source = source,
            __name = sformat("mixin:%s", sgmatch(source, ".+[/\\](.+).lua")())
        }
        if super then
            tab_copy(super.__props, mixino.__props)
            tab_copy(super.__methods, mixino.__methods)
        end
        mixin_tpl = setmetatable(mixino, mixinMT)
        mixin_tpls[source] = mixin_tpl
    end
    return mixin_tpl
end

_ENV.__mixins = mixin_tpls

--调试模式下，加入部分OOP规则检查
---------------------------------------------------------------------------------------------------
if os.getenv("DEBUG") then
    mixinMT.__close = function(mixin)
        _G.__stack_cls = mixin
    end

    mixin_call = function(mixin, method, ...)
        local mixin_method = mixin[method]
        if mixin_method then
            local _<close> = _G.__stack_cls
            _G.__stack_cls = mixin
            return mixin_method(...)
        end
    end

    mixin_private_func = function(mixin, method)
        return function(...)
            if mixin ~= _G.__stack_cls then
                warn(sformat("%s's method %s is private method.", mixin.__name, method))
                return
            end
            return mixin_call(mixin, method, ...)
        end
    end
end
