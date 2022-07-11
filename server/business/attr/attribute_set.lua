--attribute_set.lua
local qenum         = quanta.enum
local log_warn      = logger.warn

local event_mgr     = quanta.get("event_mgr")
local config_mgr    = quanta.get("config_mgr")

local AttributeSet = mixin()
local prop = property(AttributeSet)
prop:accessor("attr_set", {})           --属性集合
prop:accessor("attr_sync", false)       --属性是否同步

--委托回调
function AttributeSet:__delegate()
    local attr_db = config_mgr:get_table("attribute")
    for _, attr in attr_db:iterator() do
        AttributeSet["get_" .. attr.nick] = function(this)
            return this:get_attr(attr.id)
        end
        AttributeSet["set_" .. attr.nick] = function(this, value)
            this:set_attr(attr.id, value)
        end
    end
end

--初始化属性
function AttributeSet:init_attrset(attr_db)
    for _, attr in attr_db:iterator() do
        local attr_id = qenum("AttrID", attr.key)
        self.attr_set[attr_id] = { define = attr }
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
        attr.value = value
        if self:is_load_success() then
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
        log_warn("[AttributeSet][set_attr] attr(%s) not define", attr_id)
        return
    end
    return attr.value
end

--query
function AttributeSet:query_db_attrs()
    local attrs = {}
    for _, attr in pairs(self.attr_set) do
        local define = attr.define
        if define.save == 1 then
            attrs[define.nick] = attr.value
        end
    end
    return attrs
end

function AttributeSet:encode_attr(attr_id, value)
    if type(value) == "string" then
        return { attr_id = attr_id, attr_s = value }
    end
    return { attr_id = attr_id, attr_i = value }
end

--query
function AttributeSet:query_client_attrs(range)
    local attrs = {}
    for attr_id, attr in pairs(self.attr_set) do
        if attr.define.range == range and attr.value then
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
