--attr_component.lua
local qenum         = quanta.enum
local log_warn      = logger.warn
local log_debug     = logger.debug
local tinsert       = table.insert
local sformat       = string.format
local qmerge        = qtable.merge

local event_mgr     = quanta.get("event_mgr")
local config_mgr    = quanta.get("config_mgr")

local attr_db       = config_mgr:get_table("attribute")

local AttrComponent = mixin()
local prop = property(AttrComponent)
prop:reader("range", {})            --属性集合
prop:reader("attr_set", {})         --属性集合
prop:reader("sync_attrs", {})       --需要同步属性
prop:accessor("relay_attrs", {})    --需要转发属性
prop:accessor("write_attrs", {})    --需要回写属性
prop:accessor("relayable", false)   --是否转发属性
prop:accessor("wbackable", false)   --是否回写属性

local dbprop = db_property(AttrComponent, "player_attr", true)
dbprop:store_values("attrs", {})  --属性集合

--委托回调
function AttrComponent:__delegate()
    for _, attr in attr_db:iterator() do
        AttrComponent["get_" .. attr.nick] = function(this)
            return this:get_attr(attr.id)
        end
        AttrComponent["set_" .. attr.nick] = function(this, value)
            return this:set_attr(attr.id, value)
        end
        if attr.increase then
            AttrComponent["add_" .. attr.nick] = function(this, value)
                return this:add_attr(attr.id, value)
            end
            AttrComponent["cost_" .. attr.nick] = function(this, value)
                return this:cost_attr(attr.id, value)
            end
        end
    end
end

--初始化属性
function AttrComponent:init_attrset(type_attr_db, range)
    self.range = range or 16
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
function AttrComponent:on_db_player_attr_load(data)
    log_debug("[AttrComponent][on_db_player_attr_load] data({})", data)
    if data.player_id then
        self:load_attrs(data.attrs or {})
        return true
    end
    event_mgr:notify_trigger("on_player_attr_init", self)
    return true
end

--设置属性
--service_id表示修改源，用于同步和回写
function AttrComponent:set_attr(attr_id, value, service_id)
    local attr = self.attr_set[attr_id]
    if not attr then
        log_warn("[AttrComponent][set_attr] attr({}) not define", attr_id)
        return false
    end
    if not value then
        log_warn("[AttrComponent][set_attr] attr({}) value is nil", attr_id)
        return false
    end
    --检查限制
    if (not service_id) and attr.limit_id then
        local limit = self:get_attr(attr.limit_id)
        if limit > 0 and limit < value then
            value = limit
        end
    end
    local cur_val = self.attrs[attr_id]
    if cur_val == value then
        return true
    end
    --修改属性
    if attr.save then
        self:save_attrs_field(attr_id, value)
    else
        self:set_attrs_field(attr_id, value)
    end
    self:on_attr_changed(attr_id, attr, value, service_id)
    return true
end

--观察属性
function AttrComponent:watch_attr(trigger, attr_id, handler)
    self:watch_event(trigger, sformat("on_attr_changed_%s", attr_id), handler)
end

function AttrComponent:unwatch_attr(trigger, attr_id)
    self:unwatch_event(trigger, sformat("on_attr_changed_%s", attr_id))
end

function AttrComponent:on_attr_changed(attr_id, attr, value, service_id)
    if self:is_load_success() then
        --回写判定
        if self.wbackable and attr.back and (not service_id) then
            self.write_attrs[attr_id] = value
            event_mgr:notify_frame(self, "on_attr_writeback", self.id)
        end
        --转发判定
        if self.relayable then
            self.relay_attrs[attr_id] = { value, service_id }
            event_mgr:notify_frame(self, "on_attr_relay", self.id)
        end
        --同步属性
        if attr.range > 0 and self.range >= attr.range then
            self.sync_attrs[attr_id] = attr
            event_mgr:publish_frame(self, "on_attr_sync")
        end
        --通知改变
        self:notify_event(sformat("on_attr_changed_%s", attr_id), value, attr_id, self)
    end
end

--获取属性
function AttrComponent:get_attr(attr_id)
    return self.attrs[attr_id]
end

--检查属性
function AttrComponent:check_attr(attr_id, value)
    local ovalue = self.attrs[attr_id]
    if ovalue >= value then
        return true
    end
    return false
end

--增加属性
function AttrComponent:add_attr(attr_id, value)
    if not value then
        return false
    end
    local ovalue = self.attrs[attr_id]
    return self:set_attr(attr_id, ovalue + value)
end

--消耗属性
function AttrComponent:cost_attr(attr_id, value)
    if not value then
        return false
    end
    local ovalue = self.attrs[attr_id]
    if ovalue >= value then
        return self:set_attr(attr_id, ovalue - value)
    end
    return false
end

--加载db数据
function AttrComponent:load_attrs(attrs)
    for attr_id, value in pairs(attrs) do
        local attr = self.attr_set[attr_id]
        if not attr then
            log_warn("[AttrComponent][load_attrs] attr({}) not define", attr_id)
        end
        self:set_attrs_field(attr_id, value)
    end
end

function AttrComponent:load_relay_attrs()
    local attrs = self.relay_attrs
    self.relay_attrs = {}
    return attrs
end

function AttrComponent:merge_relay_attrs(attrs)
    local nattrs = self.relay_attrs
    self.relay_attrs = qmerge(attrs, nattrs)
end

function AttrComponent:encode_attr(attr_id, attr)
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
function AttrComponent:package_attrs(range)
    local attrs = {}
    for attr_id, attr in pairs(self.attr_set) do
        if attr.range > 0 and range >= attr.range then
            tinsert(attrs, self:encode_attr(attr_id, attr))
        end
    end
    return attrs
end

function AttrComponent:on_attr_sync()
    local attrs, battrs = {}, {}
    for attr_id, attr in pairs(self.sync_attrs) do
        if attr.range == 1 then
            tinsert(attrs, self:encode_attr(attr_id, attr))
        elseif self.range > 1 then
            tinsert(battrs, self:encode_attr(attr_id, attr))
        end
    end
    if next(attrs) then
        self:send("NID_ENTITY_ATTR_UPDATE_NTF", { id = self.id, attrs = attrs })
    end
    if self.range > 1 and next(battrs) then
        self:broadcast_message("NID_ENTITY_ATTR_UPDATE_NTF", { id = self.id, attrs = battrs })
    end
    self.sync_attrs = {}
end

return AttrComponent
