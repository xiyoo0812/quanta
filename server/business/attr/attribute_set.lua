--attribute_set.lua
local tostring      = tostring
local qenum         = quanta.enum
local log_warn      = logger.warn
local mtointeger    = math.tointeger

local event_mgr     = quanta.get("event_mgr")
local config_mgr    = quanta.get("config_mgr")

local AttributeSet = mixin()
local prop = property(AttributeSet)
prop:reader("attr_set", {})             --属性集合
prop:accessor("store_attrs", {})        --需要存储属性
prop:accessor("attr_sync", false)       --属性是否同步

--委托回调
function AttributeSet:__delegate()
    local attr_db = config_mgr:get_table("attribute")
    for _, attr in attr_db:iterator() do
        AttributeSet["get_" .. attr.nick] = function(this)
            return this:get_attr(attr.id)
        end
        AttributeSet["set_" .. attr.nick] = function(this, value)
            return this:set_attr(attr.id, value)
        end
        if attr.increase then
            AttributeSet["add_" .. attr.nick] = function(this, value)
                local old = this:get_attr(attr.id)
                return this:set_attr(attr.id, old + value)
            end
            AttributeSet["cost_" .. attr.nick] = function(this, value)
                local old = this:get_attr(attr.id)
                if old >= value then
                    return this:set_attr(attr.id, old - value)
                end
                return false
            end
        end
    end
end

--初始化属性
function AttributeSet:init_attrset(attr_db)
    for _, attr in attr_db:iterator() do
        local attr_id = qenum("AttrID", attr.key)
        local attr_def = { save = attr.save, range = attr.range }
        if attr.limit then
            attr_def.limit_id = qenum("AttrID", attr.limit)
        end
        self.attr_set[attr_id] = attr_def
    end
end

--设置属性
--source_id表示修改源，用于同步和回写
function AttributeSet:set_attr(attr_id, value, source_id)
    local attr = self.attr_set[attr_id]
    if not attr then
        log_warn("[AttributeSet][set_attr] attr(%s) not define", attr_id)
        return false
    end
    if attr.value ~= value then
        --检查限制
        if attr.limit_id then
            local limit = self:get_attr(attr.limit_id)
            if limit and limit < value then
                value = limit
            end
        end
        --修改属性
        attr.value = value
        if attr.save then
            --缓存修改
            self.store_attrs[tostring(attr_id)] = value
        end
        if self:is_load_success() then
            --通知改变
            event_mgr:notify_trigger("on_attr_changed", self, attr, attr_id, source_id)
        end
        return true
    end
    return true
end

--获取属性
function AttributeSet:get_attr(attr_id)
    local attr = self.attr_set[attr_id]
    if not attr then
        log_warn("[AttributeSet][get_attr] attr(%s) not define", attr_id)
        return
    end
    return attr.value
end

--加载db数据
function AttributeSet:load_db_attrs(attrs)
    for attr_id, value in pairs(attrs) do
        self:set_attr(mtointeger(attr_id), value)
    end
end

function AttributeSet:encode_attr(attr_id, value)
    if type(value) == "string" then
        return { attr_id = attr_id, attr_s = value }
    end
    return { attr_id = attr_id, attr_i = value }
end

--query
function AttributeSet:package_attrs(range)
    local attrs = {}
    for attr_id, attr in pairs(self.attr_set) do
        if attr.range == range and attr.value then
            local eattr = self:encode_attr(attr_id, attr.value)
            attrs[#attrs + 1] = eattr
        end
    end
    return attrs
end

--更新
function AttributeSet:_update()
end

return AttributeSet
