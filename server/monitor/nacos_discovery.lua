--nacos_discovery.lua
import("driver/nacos.lua")

local tdiff         = qtable.diff
local log_debug     = logger.debug

local nacos         = quanta.get("nacos")
local timer_mgr     = quanta.get("timer_mgr")

local NAMESPACE     = environ.get("QUANTA_NAMESPACE")

local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_5_MS   = quanta.enum("PeriodTime", "SECOND_5_MS")

local NacosDiscovery = class()
local prop = property(NacosDiscovery)
prop:reader("trigger", nil)
prop:reader("timer_id", nil)
prop:reader("services", {})
prop:reader("groups", {})
prop:reader("locals", {})

function NacosDiscovery:__init(trigger)
    --初始化变量
    self.trigger = trigger
    --设置
    self:setup()
end

function NacosDiscovery:setup()
    --梳理服务
    for service_name, service_id in pairs(service.services()) do
        self.services[service_name] = {}
        self.groups[service_name] = service_id
    end
    nacos:setup(NAMESPACE)
    --配置nacos
    timer_mgr:once(SECOND_MS, function()
        nacos:modify_switchs("healthCheckEnabled", "false")
        nacos:modify_switchs("autoChangeHealthCheckEnabled", "false")
        --注册自己
        self:register(quanta.node_info)
        --初始化定时器
        self:check_services()
    end)
end

function NacosDiscovery:check_services(time)
    if self.timer_id then
        timer_mgr:unregister(self.timer_id)
    end
    self:refresh_services()
    self.timer_id = timer_mgr:once(time or SECOND_5_MS, function()
        self:check_services()
    end)
end

function NacosDiscovery:refresh_services()
    for service_name in pairs(self.groups) do
        local curr = nacos:query_instances(service_name)
        if curr then
            local old = self.services[service_name]
            local sadd, sdel = tdiff(old, curr)
            if next(sadd) or next(sdel) then
                log_debug("[NacosDiscovery][check_services] sadd:%s, sdel: %s", sadd, sdel)
                self.trigger:broadcast("rpc_service_changed", service_name, sadd, sdel)
                self.services[service_name] = curr
            end
        end
    end
    --发送心跳
    self:heartbeat(quanta.id)
end

-- 心跳
function NacosDiscovery:heartbeat(node_id)
    local sdata = self.locals[node_id]
    if sdata then
        if not sdata.status then
            local status = nacos:regi_instance(sdata.service_name, sdata.host, sdata.port, nil, sdata.metadata)
            if not status then
                return
            end
            sdata.status = true
        end
        nacos:sent_beat(sdata.name, sdata.host, sdata.port)
    end
end

--注册服务
function NacosDiscovery:register(node)
    local metadata = { region = node.region, group = node.group, id = node.id, name = node.name }
    local service_data = { service_name = node.service_name, host = node.host, port = node.port, metadata = metadata }
    service_data.status = nacos:regi_instance(node.service_name, node.host, node.port, nil, metadata)
    self.locals[node.id] = service_data
end

-- 会话关闭回调
function NacosDiscovery:unregister(node_id)
    local sdata = self.locals[node_id]
    if sdata then
        nacos:del_instance(sdata.service_name, sdata.host, sdata.port)
        self:refresh_services(SECOND_MS)
    end
end

return NacosDiscovery
