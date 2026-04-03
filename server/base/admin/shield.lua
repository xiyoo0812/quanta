-- shield.lua
local log_info      = logger.info

local event_mgr     = quanta.get("event_mgr")

local Shield = singleton()
local prop = property(Shield)
prop:accessor("filters", {})
prop:accessor("services", {})

function Shield:__init()
    -- 添加过滤
    event_mgr:add_listener(self, "rpc_add_proto_shield")
    -- 删除过滤
    event_mgr:add_listener(self, "rpc_del_proto_shield")
    -- 清理过滤
    event_mgr:add_listener(self, "rpc_shield_service_proto")
    -- 事件监听
    event_mgr:add_listener(self, "on_proto_filter")
end

-- 验证过滤
function Shield:on_proto_filter(cmd_id, server_type)
    -- 验证协议拦截器
    if self.filters[cmd_id] then
        return true
    end
    if self.services[server_type] then
        return true
    end
    return false
end

-- 添加协议过滤
function Shield:rpc_add_proto_shield(start_cmd_id, count)
    local end_cmd_id = start_cmd_id + count - 1
    for cmd_id = start_cmd_id, end_cmd_id do
        self.filters[cmd_id] = true
    end
    log_info("[Shield][rpc_add_shield] start_cmd_id={} count={}", start_cmd_id, count)
end

-- 删除协议过滤
function Shield:rpc_del_proto_shield(start_cmd_id, count)
    local end_cmd_id = start_cmd_id + count - 1
    for cmd_id = start_cmd_id, end_cmd_id do
        self.filters[cmd_id] = nil
    end
    log_info("[Shield][rpc_del_shield] start_cmd_id={} count={}", start_cmd_id, count)
end

-- 清理过滤协议
function Shield:rpc_shield_service_proto(service_type, status)
    log_info("[Shield][rpc_shield_service_proto] service_type={} status={}", service_type, status)
    self.services[service_type] = status
end

-- export
quanta.Shield = Shield()
return Shield
