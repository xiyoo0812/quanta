--redis_discovery.lua

local tonumber      = tonumber
local log_err       = logger.err
local log_debug     = logger.debug
local tunpack       = table.unpack
local tinsert       = table.insert
local sformat       = string.format
local sid2name      = service.id2name
local json_decode   = json.decode

local timer_mgr     = quanta.get("timer_mgr")
local event_mgr     = quanta.get("event_mgr")
local RedisDB       = import("driver/redis.lua")
local PSRedis       = import("driver/redisps.lua")

local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")
local EXPIRETIME    = quanta.enum("PeriodTime", "SECOND_30_S")

local CLUSTER       = environ.get("QUANTA_CLUSTER")
local SERVICE_KEY   = sformat("QUANTA:service:%s", CLUSTER)
local CHANNEL_DN    = sformat("%s.unregister", CLUSTER)
local CHANNEL_UP    = sformat("%s.register", CLUSTER)
local CHANNEL_PT    = sformat("%s.*", CLUSTER)

local RedisDiscovery = class()
local prop = property(RedisDiscovery)
prop:reader("redis", nil)
prop:reader("trigger", nil)
prop:reader("timer_id", nil)
prop:reader("subscriber", nil)
prop:reader("services", {})
prop:reader("routers", {})
prop:reader("locals", {})

function RedisDiscovery:__init(trigger)
    --设置
    self:setup()
    --初始化变量
    self.trigger = trigger
    --事件
    event_mgr:add_trigger(self, "on_subscribe_ready")
    event_mgr:add_trigger(self, "on_subscribe_alive")
end

function RedisDiscovery:setup()
    local driver = environ.driver("QUANTA_REDIS_URL")
    self.redis = RedisDB(driver)
    self.subscriber = PSRedis(driver)
    if not self.redis then
        log_err("[RedisDiscovery][setup] discovery config err: driver is empty")
        return
    end
    --初始化定时器
    timer_mgr:loop(SECOND_10_MS, function()
        self:check_heartbeat(quanta.now)
    end)
    --注册自己
    event_mgr:fire_second(function()
        self:register(quanta.node_info)
    end)
end

function RedisDiscovery:load_services()
    local querys = self:query_instances()
    if not querys then
        return
    end
    --梳理服务
    for _, service_name in pairs(service.services()) do
        self.services[service_name] = {}
    end
    for _, node in pairs(querys) do
        local sname = sid2name(node.id)
        if sname == "router" then
            self.routers[node.id] = node
        else
            self.services[sname][node.id] = node
        end
    end
end

function RedisDiscovery:on_subscribe_alive()
    log_debug("[RedisDiscovery][on_subscribe_alive]")
    self.subscriber:execute("psubscribe", CHANNEL_PT)
    self:load_services()
end

function RedisDiscovery:on_subscribe_ready(channel, data)
    local node_data = json_decode(data)
    local node_id = node_data.id
    local sname = sid2name(node_id)
    if channel == CHANNEL_UP then
        log_debug("[RedisDiscovery][quanta_register] data:{}", data)
        if sname == "router" then
            self.routers[node_id] = node_data
            self.trigger:broadcast("rpc_service_changed", sname, { [node_id] = node_data }, {})
            return
        end
        self.services[sname][node_id] = node_data
        self.trigger:broadcast_legal("rpc_service_changed", sname, { [node_id] = node_data }, {})
    end
    if channel == CHANNEL_DN then
        log_debug("[RedisDiscovery][quanta_unregister] data:{}", data)
        if sname == "router" then
            self.routers[node_id] = nil
            self.trigger:broadcast("rpc_service_changed", sname, {}, { [node_id] = node_data })
            return
        end
        self.services[sname][node_id] = nil
        self.trigger:broadcast_legal("rpc_service_changed", sname, {}, { [node_id] = node_data })
    end
end

-- 心跳
function RedisDiscovery:check_heartbeat(now)
    local fields = {}
    for _, sdata in pairs(self.locals) do
        tinsert(fields, sdata)
        tinsert(fields, now)
    end
    if next(fields) then
        self.redis:execute("HMSET", SERVICE_KEY, tunpack(fields))
    end
end

--注册服务
function RedisDiscovery:register(node)
    if not self.services[node.service_name] then
        return
    end
    local fmt = [[{"id":%d,"port":%d,"ip":"%s","region":%d,"name":"%s"}]]
    local node_data = sformat(fmt, node.id, node.port, node.host, node.region, node.name)
    self:regi_instance(node_data)
    self.locals[node.id] = node_data
end

-- 会话关闭回调
function RedisDiscovery:unregister(node_id)
    local sdata = self.locals[node_id]
    if sdata then
        self.locals[node_id] = nil
        log_debug("[RedisDiscovery][unregister] node {}", node_id)
        self:del_instance(sdata)
    end
end

--redis接口
--------------------------------------------------------------------
-- 查询所有实例
function RedisDiscovery:query_instances()
    local cur = 0
    local results = {}
    local now = quanta.now
    repeat
        local ok, next_cur, datas = self.redis:execute("HSCAN", SERVICE_KEY, cur, "count", 200)
        if not ok or not next_cur or not datas then
            log_err("[RedisDiscovery][query_instances] query failed: cur:{}, datas:{}", next_cur, datas)
            return
        end
        for node_data, score in pairs(datas) do
            if tonumber(score) > now - EXPIRETIME then
                tinsert(results, json_decode(node_data))
            end
        end
        cur = next_cur
    until cur == 0
    return results
end

-- 注册实例
function RedisDiscovery:regi_instance(node_data)
    self.redis:execute("HSET", SERVICE_KEY, node_data, quanta.now)
    self.redis:execute("publish", CHANNEL_UP, node_data)
end

-- 删除实例
function RedisDiscovery:del_instance(node_data)
    self.redis:execute("HDEL", SERVICE_KEY, node_data)
    self.redis:execute("publish", CHANNEL_DN, node_data)
end

return RedisDiscovery
