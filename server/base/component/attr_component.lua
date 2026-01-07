--attr_component.lua
local qenum         = quanta.enum
local log_warn      = logger.warn
local tinsert       = table.insert
local supper        = string.upper
local sformat       = string.format

local event_mgr     = quanta.get("event_mgr")
local config_mgr    = quanta.get("config_mgr")

local attr_db       = config_mgr:get_table("attribute")

local AttrID        = enum("AttrID")
local COMPLEX_ID    = 1000

--复合属性定义: { 后缀，类型，是否存库}
local COMPLEX_NAMES = {
    { "_base",  false,  "int" },
    { "_inc",   false,  "int" },
    { "_per",   false,  "float" },
    { "_fin",   true,   "int" }
}

local AttrComponent = mixin()
local prop = property(AttrComponent)
prop:reader("range", 1)             --属性同步范围
prop:reader("attr_set", {})         --属性集合
prop:reader("sync_attrs", {})       --同步属性
prop:accessor("share_attrs", {})    --共享属性
prop:accessor("slavable", false)    --是否复制体

local store = storage(AttrComponent, "player_attr")
store:store_values("attrs", {})  --属性集合

--加载db数据
function AttrComponent:on_db_player_attr_load(data)
    if data.player_id then
        self:load_attrs(data.attrs or {})
        event_mgr:notify_trigger("on_player_attr_init", self)
        return
    end
    event_mgr:notify_trigger("on_player_attr_init", self, true)
    return true
end

--委托回调
function AttrComponent:__delegate()
    local function delegate_attr(attr)
        AttrComponent["get_" .. attr.nick] = function(this)
            if attr.type ~= "string" then
                return this:get_attr(attr.id) // 1
            end
            return this:get_attr(attr.id)
        end
        AttrComponent["set_" .. attr.nick] = function(this, value)
            return this:set_attr(attr.id, value)
        end
        if attr.increase then
            AttrComponent["add_" .. attr.nick] = function(this, value)
                if value < 0 then
                    return this:sub_attr(attr.id, -value)
                end
                return this:add_attr(attr.id, value)
            end
            AttrComponent["sub_" .. attr.nick] = function(this, value)
                if value < 0 then
                    return this:add_attr(attr.id, -value)
                end
                return this:sub_attr(attr.id, value)
            end
            AttrComponent["cost_" .. attr.nick] = function(this, value)
                if value <= 0 then
                    return false
                end
                return this:cost_attr(attr.id, value)
            end
        end
    end
    local function delegate_complex_attr(complex_id, attr)
        for idx, info in ipairs(COMPLEX_NAMES) do
            AttrID[attr.enum_key .. supper(info[1])] = complex_id + idx
            delegate_attr({ id = complex_id + idx, nick = attr.nick .. info[1], increase = true })
        end
    end
    for _, attr in attr_db:iterator() do
        if attr.complex then
            local complex_id = COMPLEX_ID + attr.id * 4
            delegate_complex_attr(complex_id, attr)
            AttrComponent["get_" .. attr.nick] = function(this)
                return this:get_attr(attr.id) // 1
            end
        else
            delegate_attr(attr)
        end
    end
end

--停止对某个服务属性共享
function AttrComponent:stop_share(service_name)
    for _, attr_info in pairs(self.attr_set) do
        if attr_info.services[service_name] then
            attr_info.services[service_name] = nil
        end
    end
end

--初始化属性
function AttrComponent:init_attr(attr_type, attr_id, attr_info)
    self.attr_set[attr_id] = attr_info
    if attr_type == "string" or attr_type == "bytes" then
        self.attrs[attr_id] = ""
    else
        self.attrs[attr_id] = 0
    end
end

--绑定属性
function AttrComponent:bind_attr(attr_id, attr, service_name)
    local oattr_info = self.attr_set[attr_id]
    if oattr_info then
        if service_name then
            oattr_info.services[service_name] = true
        end
        return
    end
    local attr_opt = attr_db:find_one(attr_id)
    if attr_opt.complex then
        for idx, info in ipairs(COMPLEX_NAMES) do
            --复合子属性不同步
            local complex_id = COMPLEX_ID + attr_id * 4 + idx
            local complex_info = { save = info[2], type = info[3], range = 0, share = attr.share, services = {}, base = attr_id }
            self:init_attr(info[3], complex_id , complex_info)
        end
        --复合属性不共享，不存储
        local attr_info = { save = false, share = false, range = attr.range, type = attr_opt.type, services = {} }
        self:init_attr(attr_opt.type, attr_id, attr_info)
    else
        local attr_info = { save = attr.save, share = attr.share, range = attr.range, type = attr_opt.type, services = {} }
        if attr_opt.limit then
            attr_info.limit_id = qenum("AttrID", attr_opt.limit)
        end
        self:init_attr(attr_opt.type, attr_id, attr_info)
    end
end

--初始化属性
function AttrComponent:init_attrset(type_attr_db, range)
    self.range = range or 16
    for _, attr in type_attr_db:iterator() do
        self:bind_attr(qenum("AttrID", attr.key), attr)
    end
end


--设置属性
--service_id 表示修改源，用于同步和回写
function AttrComponent:set_attr(attr_id, value, service_id)
    local attr = self.attr_set[attr_id]
    if not attr or not value then
        log_warn("[AttrComponent][set_attr] attr({}-{}) is not vaild", attr_id, value)
        return false
    end
    if attr.complex then
        log_warn("[AttrComponent][set_attr] attr({}) value is complex", attr_id)
        return false
    end
    --检查限制
    if not service_id then
        if attr.limit_id then
            local limit = self:get_attr(attr.limit_id)
            if limit > 0 and limit < value then
                value = limit
            end
        end
        if attr.type == "uint" then
            if value < 0 then
                value = 0
            end
        end
    end
    local cur_val = self.attrs[attr_id]
    if cur_val == value then
        return true, value, value
    end
    --修改属性
    if attr.save then
        self:save_attrs_field(attr_id, value)
    else
        self:set_attrs_field(attr_id, value)
    end
     --复合属性
    if attr.base then
        self:update_attr(attr.base)
    end
    self:on_attr_changed(attr_id, attr, value, cur_val, service_id)
    return true, value, cur_val
end

--强制保存属性
function AttrComponent:flush_attr(attr_id)
    self:flush_attrs_field(attr_id)
end

--观察属性
function AttrComponent:watch_attr(trigger, attr_id, handler)
    self:watch_event(trigger, sformat("on_attr_changed_%s", attr_id), handler)
end

--取消观察属性
function AttrComponent:unwatch_attr(trigger, attr_id)
    self:unwatch_event(trigger, sformat("on_attr_changed_%s", attr_id))
end

--属性变化处理
function AttrComponent:on_attr_changed(attr_id, attr, value, oldval, service_id)
    if self:is_load_success() then
        if (not service_id) and attr.share then
            --共享属性处理
            self.share_attrs[attr_id] = { value, attr.services }
            if self.slavable then
                event_mgr:notify_frame(self, "on_attr_writeback", self.id)
            else
                event_mgr:notify_frame(self, "on_attr_relay", self.id)
            end
        end
        self:notify_attr(attr_id, value, oldval, attr)
    end
end

--计算复合属性
function AttrComponent:update_attr(attr_id)
    local complex_id = COMPLEX_ID + attr_id * 4
    local base = self:get_attr(complex_id + 1)
    local inc = self:get_attr(complex_id + 2)
    local per = self:get_attr(complex_id + 3)
    local fin = self:get_attr(complex_id + 4)
    local value = ((base + inc) * (1 + per) + fin)
    local cur_val = self.attrs[attr_id]
    if cur_val == value then
        return
    end
    self:set_attrs_field(attr_id, value)
    --通知改变
    if self:is_load_success() then
        self:notify_attr(attr_id, value, cur_val, self.attr_set[attr_id])
    end
end

--属性改变通知
function AttrComponent:notify_attr(attr_id, value, oldval, attr)
    if attr.range > 0 and self.range >= attr.range then
        self.sync_attrs[attr_id] = attr
        event_mgr:publish_frame(self, "on_attr_update")
    end
    self:notify_event(sformat("on_attr_changed_%s", attr_id), attr_id, value, oldval, self)
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

--加属性
function AttrComponent:add_attr(attr_id, value)
    if not value then
        return false
    end
    local ovalue = self.attrs[attr_id]
    return self:set_attr(attr_id, ovalue + value)
end

--减属性
function AttrComponent:sub_attr(attr_id, value)
    if not value then
        return false
    end
    local nvalue = self.attrs[attr_id] - value
    return self:set_attr(attr_id, nvalue)
end

--消耗属性
function AttrComponent:cost_attr(attr_id, value)
    if not value then
        return false
    end
    local nvalue = self.attrs[attr_id] - value
    if nvalue >= 0 then
        return self:set_attr(attr_id, nvalue)
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

--收集全量共享属性
function AttrComponent:collect_share_attrs(service_name)
    local attrs = {}
    for attr_id, value in pairs(attrs) do
        local attr = self.attr_set[attr_id]
        if attr.services[service_name] then
            attrs[attr_id] = value
        end
    end
    return attrs
end

--获取变化的共享属性
function AttrComponent:load_share_attrs()
    local attrs = self.share_attrs
    self.share_attrs = {}
    return attrs
end

--合并变化的共享属性
function AttrComponent:merge_share_attrs(attrs)
    for attr_id, args in pairs(attrs) do
        if not self.share_attrs[attr_id] then
            self.share_attrs[attr_id] = args
        end
    end
end

--编码属性
function AttrComponent:encode_attr(attr_id, attr)
    local value = self.attrs[attr_id]
    if attr.type == "uint" or attr.type == "int" then
        return { attr_id = attr_id, attr_i = value // 1 }
    end
    if attr.type == "string" then
        return { attr_id = attr_id, attr_s = value }
    end
    if attr.type == "float" then
        return { attr_id = attr_id, attr_f = value }
    end
    return { attr_id = attr_id, attr_b = value }
end

--打包需要同步的属性
function AttrComponent:package_attrs(range)
    local attrs = {}
    for attr_id, attr in pairs(self.attr_set) do
        if attr.range >= range then
            tinsert(attrs, self:encode_attr(attr_id, attr))
        end
    end
    return attrs
end

--属性更新处理
function AttrComponent:on_attr_update()
    local attrs, battrs = {}, {}
    for attr_id, attr in pairs(self.sync_attrs) do
        local eattr = self:encode_attr(attr_id, attr)
        tinsert(attrs, eattr)
        if attr.range > 1 then
            tinsert(battrs, eattr)
        end
    end
    event_mgr:notify_trigger("on_attr_synchronous", self, self.id, attrs, battrs)
    self.sync_attrs = {}
end

--获取复合ID
function AttrComponent:complex_id(attr_id)
    return COMPLEX_ID + attr_id * 4
end

return AttrComponent
