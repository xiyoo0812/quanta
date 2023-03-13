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
prop:reader("sync_attrs", {})       --需要同步属性
prop:accessor("relay_attrs", {})    --需要转发属性
prop:accessor("write_attrs", {})    --需要回写属性
prop:accessor("relayable", false)   --是否转发属性
prop:accessor("wbackable", false)   --是否回写属性

local dbprop = db_property(AttributeSet, "player_attr")
dbprop:store_values("attrs", {})  --属性集合

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
        local attr_type = attr_db:find_value("type", attr_id)
        local attr_def = { save = attr.save, back = attr.back, range = attr.range, type = attr_type }
        if attr.limit then
            attr_def.limit_id = qenum("AttrID", attr.limit)
        end
        self.attr_set[attr_id] = attr_def
        self.attrs[attr_id] = attr_type == "int" and 0 or ""
    end
end

--加载db数据
function AttributeSet:on_db_player_attr_load(data)
    if data and data.player_attr then
        self:load_attrs(data.player_attr)
        return true
    end
    event_mgr:notify_trigger("on_player_attr_init", self)
    local attrs = self:pack_db_attrs()
    self:flush_player_attr(attrs)
    return true
end

--设置属性
--source_id表示修改源，用于同步和回写
function AttributeSet:set_attr(attr_id, value, source_id)
    local attr, cur_val = self.attr_set[attr_id], self.attrs[attr_id]
    if not attr or not cur_val then
        log_warn("[AttributeSet][set_attr] attr(%s) not define", attr_id)
        return false
    end
    if cur_val ~= value then
        --检查限制
        if attr.limit_id then
            local limit = self:get_attr(attr.limit_id)
            if limit > 0 and limit < value then
                value = limit
            end
        end
        --修改属性
        if attr.save then
            self:set_attrs_field(attr_id, value)
        else
            self.attrs[attr_id] = value
        end
        self:on_attr_changed(attr_id, attr, value, source_id)
        return true
    end
    return true
end

function AttributeSet:on_attr_changed(attr_id, attr, value, source_id)
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
end

--获取属性
function AttributeSet:get_attr(attr_id)
    local value = self.attrs[attr_id]
    if not value then
        log_warn("[AttributeSet][get_attr] attr(%s) not define", attr_id)
        return
    end
    return value
end

--检查属性
function AttributeSet:check_attr(attr_id, value)
    local ovalue = self.attrs[attr_id]
    if ovalue >= value then
        return true
    end
    return false
end

--增加属性
function AttributeSet:add_attr(attr_id, value)
    local ovalue = self.attrs[attr_id]
    return self:set_attr(attr_id, ovalue + value)
end

--消耗属性
function AttributeSet:cost_attr(attr_id, value)
    local ovalue = self.attrs[attr_id]
    if ovalue >= value then
        return self:set_attr(attr_id, ovalue - value)
    end
    return false
end

--加载db数据
function AttributeSet:load_attrs(attrs)
    for attr_id, value in pairs(attrs) do
        local attr = self.attr_set[attr_id]
        if not attr then
            log_warn("[AttributeSet][load_attrs] attr(%s) not define", attr_id)
            return false
        end
        self.attrs[attr_id] = value
    end
end

function AttributeSet:encode_attr(attr_id, attr)
    local value = self.attrs[attr_id]
    if attr.type == "int" then
        return { attr_id = attr_id, attr_i = value }
    end
    if attr.type == "string" then
        return { attr_id = attr_id, attr_s = value }
    end
    return { attr_id = attr_id, attr_b = value }
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

--package_sync_attrs
function AttributeSet:package_sync_attrs(range)
    local attrs = {}
    for attr_id, attr in pairs(self.sync_attrs) do
        if attr.range == range then
            tinsert(attrs, self:encode_attr(attr_id, attr))
        end
    end
    self.sync_attrs = {}
    return attrs
end

--pack_db_attrs
function AttributeSet:pack_db_attrs()
    local attrs = {}
    for attr_id, attr in pairs(self.attr_set) do
        if attr.save then
            attrs[attr_id] = self.attrs[attr_id]
        end
    end
    return { attrs = attrs }
end

--更新
function AttributeSet:_update()
end

return AttributeSet
