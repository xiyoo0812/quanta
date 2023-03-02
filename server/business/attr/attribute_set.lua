--attribute_set.lua
local qenum         = quanta.enum
local log_warn      = logger.warn
local tinsert       = table.insert

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")
local config_mgr    = quanta.get("config_mgr")

local attr_db       = config_mgr:get_table("attribute")

local AttributeSet = mixin()
local prop = property(AttributeSet)
prop:reader("attr_set", {})         --属性集合
prop:reader("attr_types", {})       --属性类型
prop:reader("sync_attrs", {})       --需要同步属性
prop:accessor("store_attrs", {})    --需要存储属性
prop:accessor("relay_attrs", {})    --需要转发属性
prop:accessor("write_attrs", {})    --需要回写属性
prop:accessor("relayable", false)   --是否转发属性
prop:accessor("wbackable", false)   --是否回写属性

--委托回调
function AttributeSet:__delegate()
    for _, attr in attr_db:iterator() do
        AttributeSet["get_" .. attr.nick] = function(this)
            return this:get_attr(attr.id)
        end
        AttributeSet["set_" .. attr.nick] = function(this, value)
            return this:set_attr(attr.id, value)
        end
        if attr.increase then
            AttributeSet["add_" .. attr.nick] = function(this, value)
                return this:add_attr(attr.id, value)
            end
            AttributeSet["cost_" .. attr.nick] = function(this, value)
                return this:cost_attr(attr.id, value)
            end
        end
    end
end

--初始化属性
function AttributeSet:init_attrset(type_attr_db)
    for _, attr in type_attr_db:iterator() do
        local attr_id = qenum("AttrID", attr.key)
        local attr_def = { save = attr.save, back = attr.back, range = attr.range, value = 0 }
        if attr.limit then
            attr_def.limit_id = qenum("AttrID", attr.limit)
        end
        attr_def.type = attr_db:find_value("type", attr_id)
        if attr_def.type ~= "int" then
            attr_def.value = ""
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
            if limit > 0 and limit < value then
                value = limit
            end
        end
        --修改属性
        attr.value = value
        if attr.save then
            --缓存修改
            self.store_attrs[attr_id] = value
        end
        local eid = self.id
        if self:is_load_success() then
            --回写判定
            if self.wbackable and attr.back and (not source_id) then
                self.write_attrs[attr_id] = attr.value
                update_mgr:attach_event(eid, "on_attr_writeback", eid, self)
            end
            --转发判定
            if self.relayable then
                self.relay_attrs[attr_id] = { value, source_id }
                update_mgr:attach_event(eid, "on_attr_relay", eid, self)
            end
            --同步属性
            if attr.range > 0 then
                self.sync_attrs[attr_id] = attr
                update_mgr:attach_event(eid, "on_attr_sync", eid, self)
            end
            --通知改变
            event_mgr:notify_trigger("on_attr_changed", self, eid, attr_id, value)
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

--检查属性
function AttributeSet:check_attr(attr_id, value)
    local ovalue = self:get_attr(attr_id)
    if ovalue >= value then
        return true
    end
    return false
end

--增加属性
function AttributeSet:add_attr(attr_id, value)
    local ovalue = self:get_attr(attr_id)
    return self:set_attr(attr_id, ovalue + value)
end

--消耗属性
function AttributeSet:cost_attr(attr_id, value)
    local ovalue = self:get_attr(attr_id)
    if ovalue >= value then
        return self:set_attr(attr_id, ovalue - value)
    end
    return false
end

--加载db数据
function AttributeSet:load_db_attrs(attrs)
    for attr_id, value in pairs(attrs) do
        local attr = self.attr_set[attr_id]
        if not attr then
            log_warn("[AttributeSet][load_db_attrs] attr(%s) not define", attr_id)
            return false
        end
        attr.value = value
    end
end

function AttributeSet:encode_attr(attr_id, attr)
    if attr.type == "int" then
        return { attr_id = attr_id, attr_i = attr.value }
    end
    if attr.type == "string" then
        return { attr_id = attr_id, attr_s = attr.value }
    end
    return { attr_id = attr_id, attr_b = attr.value }
end

--package_attrs
function AttributeSet:package_attrs(range)
    local attrs = {}
    for attr_id, attr in pairs(self.attr_set) do
        if attr.range == range then
            tinsert(attrs, self:encode_attr(attr_id, attr))
        end
    end
    return attrs
end

--packet_sync_attrs
function AttributeSet:packet_sync_attrs(range)
    local attrs = {}
    for attr_id, attr in pairs(self.sync_attrs) do
        if attr.range == range then
            tinsert(attrs, self:encode_attr(attr_id, attr))
        end
    end
    self.sync_attrs = {}
    return attrs
end

--更新
function AttributeSet:_update()
end

return AttributeSet
