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
local tinsert       = table.insert
local setmetatable  = setmetatable
local dtraceback    = debug.traceback
local ogetenv       = os.getenv

local mixin_tpls    = _ENV.__mixins or {}

local function mixin_call(mixin, method, ...)
    local mixin_method = mixin[method]
    if mixin_method then
        return mixin_method(...)
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

-- 递归获取所有方法
local function find_methods(mixin)
    local methods = {}
    local cur = mixin
    while cur do
        for method in pairs(cur.__methods) do
            if not methods[method] then
                methods[method] = true
            end
        end
        cur = cur.__super
    end
    return methods
end

local function delegate_func(class, mixin, method)
    if ssub(method, 1, 2) == "__" then
        return
    end
    if class[method] then
        warn(sformat("%s delegate %s method %s is repeat.", class.__name, mixin.__name, method))
        return
    end
    --接口代理
    class[method] = function(...)
        return mixin[method](...)
    end
end

--代理一个组件
local function delegate_one(class, mixin)
    if mixin.__delegate then
        mixin.__delegate()
    end
    for name, info in pairs(mixin.__props) do
        if class.__props[name] then
            warn(sformat("%s delegate %s prop %s is repeat.", class.__name, mixin.__name, name))
            return
        end
        class.__props[name] = info
    end
    local methods = find_methods(mixin)
    for method in pairs(methods) do
        delegate_func(class, mixin, method)
    end
    tinsert(class.__mixins, mixin)
    tinsert(mixin.__owners, class)
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
    --定义委托接口，在声明后添加委托
    local vtbl = class.__vtbl
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

--传播新方法并代理
local function propagate_new_method(mixin, method)
    for _, class in ipairs(mixin.__owners) do
        if not class[method] then
            class[method] = function(...)
                return mixin[method](...)
            end
        end
    end
    for _, submixin in pairs(mixin.__submixins) do
        propagate_new_method(submixin, method)
    end
end

local function mt_index(mixin, field)
    return mixin.__methods[field]
end

local function mt_newindex(mixin, field, value)
    if rawget(mixin.__methods, field) then
        if ssub(field, 1, 2) ~= "__" and not ogetenv("HOTFIX") then
            warn(sformat("mixin %s: %s has repeat defined.", mixin.__name, field))
        end
    end
    mixin.__methods[field] = value
    --新增方法代理
    propagate_new_method(mixin, field)
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
            __submixins = {},
            __super = super,
            __source = source,
            __name = sformat("mixin:%s", sgmatch(source, ".+[/\\](.+).lua")())
        }
        if super then
            tab_copy(super.__props, mixino.__props)
            setmetatable(mixino.__methods, { __index = super })
            super.__submixins[source] = mixino
        end
        mixin_tpl = setmetatable(mixino, mixinMT)
        mixin_tpls[source] = mixin_tpl
    end
    return mixin_tpl
end

_ENV.__mixins = mixin_tpls
