--redis_discovery.lua
local ljson         = require("lcjson")

local tdiff         = qtable.diff
local log_err       = logger.err
local log_debug     = logger.debug
local tunpack       = table.unpack
local sformat       = string.format
local json_encode   = ljson.encode
local json_decode   = ljson.decode

local timer_mgr     = quanta.get("timer_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local RedisDB       = import("driver/redis.lua")

local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_5_MS   = quanta.enum("PeriodTime", "SECOND_5_MS")

local EXPIRETIME    = 30
local NAMESPACE     = environ.get("QUANTA_NAMESPACE")

local RedisDiscovery = class()
local prop = property(RedisDiscovery)
prop:reader("redis", nil)
prop:reader("trigger", nil)
prop:reader("timer_id", nil)
prop:reader("services", {})
prop:reader("origins", {})
prop:reader("groups", {})
prop:reader("locals", {})

function RedisDiscovery:__init(trigger)
    --初始化变量
    self.trigger = trigger
    --设置
    self:setup()
end

function RedisDiscovery:setup()
    local drivers = environ.driver("QUANTA_REDIS_URLS")
    for i, conf in ipairs(drivers) do
        if conf.driver == "redis" then
            self.redis = RedisDB(conf)
            break
        end
    end
    --梳理服务
    for _, service_name in pairs(service.services()) do
        self.services[service_name] = {}
        self.groups[service_name] = sformat("QUANTA:%s:%s*", NAMESPACE, service_name)
    end
    --初始化定时器
    timer_mgr:once(SECOND_MS, function()
        --注册自己
        self:register(quanta.node_info)
        self:check_services()
    end)
end

function RedisDiscovery:check_services(time)
    if self.timer_id then
        timer_mgr:unregister(self.timer_id)
    end
    thread_mgr:fork(function()
        --发送心跳
        self:heartbeat(quanta.id)
        --检查服务
        self:refresh_services()
    end)
    self.timer_id = timer_mgr:once(time or SECOND_5_MS, function()
        self:check_services()
    end)
end

function RedisDiscovery:refresh_services()
    for service_name, service_key in pairs(self.groups) do
        local querys = self:query_instances(service_key)
        if querys and next(querys) then
            local news = {}
            local cur_services = self.services[service_name]
            local cur_origins = self.origins[service_name] or {}
            local sadd, sdel = tdiff(cur_origins, querys)
            for _, matadata in pairs(sadd) do
                local meta = json_decode(matadata)
                cur_services[meta.id] = meta
                news[meta.id] = meta
            end
            for id in pairs(sdel) do
                cur_services[id] = nil
            end
            if next(news) or next(sdel) then
                log_debug("[RedisDiscovery][check_services] sadd:%s, sdel: %s", news, sdel)
                self.trigger:broadcast("rpc_service_changed", service_name, news, sdel)
            end
            self.origins[service_name] = querys
        end
    end
end

-- 心跳
function RedisDiscovery:heartbeat(node_id)
    local sdata = self.locals[node_id]
    if sdata then
        if not sdata.status then
            local status = self:regi_instance(sdata.service_key, sdata.metadata)
            if not status then
                return
            end
            sdata.status = true
        end
        self.redis:execute("EXPIRE", sdata.service_key, EXPIRETIME)
    end
end

--注册服务
function RedisDiscovery:register(node)
    local metadata = { region = node.region, group = node.group, id = node.id, name = node.name, ip = node.host, port = node.port }
    local service_key = sformat("QUANTA:%s:%s:%s", NAMESPACE, node.service_name, node.index)
    local service_data = { service_key = service_key, metadata = json_encode(metadata) }
    service_data.status = self:regi_instance(service_key, service_data.metadata)
    self.locals[node.id] = service_data
end

-- 会话关闭回调
function RedisDiscovery:unregister(node_id)
    local sdata = self.locals[node_id]
    if sdata then
        self:del_instance(sdata.service_key)
        self:refresh_services(SECOND_MS)
    end
end

--redis接口
--------------------------------------------------------------------
-- 查询所有实例
function RedisDiscovery:query_instances(service_key)
    local ok, skeys = self.redis:execute("KEYS", service_key)
    if not ok then
        log_err("[RedisDiscovery][query_instances] query nodes %s failed: %s", service_key, skeys)
        return
    end
    if skeys and next(skeys) then
        local ok2, values = self.redis:execute("MGET", tunpack(skeys))
        if not ok2 then
            log_err("[RedisDiscovery][query_instances] query node infos %s failed: %s", service_key, values)
            return
        end
        return values
    end
end

-- 发送心跳
function RedisDiscovery:sent_beat(service_key)
    thread_mgr:fork(function()
        self.redis:execute("EXPIRE", service_key, EXPIRETIME)
    end)
end

-- 注册实例
function RedisDiscovery:regi_instance(service_key, metadata)
    local ok, res = self.redis:execute("SETEX", service_key, EXPIRETIME, metadata)
    if not ok then
        log_err("[RedisDiscovery][regi_instance] register %s failed: %s", service_key, res)
    end
    return ok
end

-- 删除实例
function RedisDiscovery:del_instance(service_key)
    local ok, res = self.redis:execute("DEL", service_key)
    if not ok then
        log_err("[RedisDiscovery][del_instance] del %s failed: %s", service_key, res)
    end
end

return RedisDiscovery
