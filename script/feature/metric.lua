--metric.lua
local tnow_ms       = timer.now_ms
local log_debug     = logger.debug

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")
local prometheus    = quanta.get("prometheus")

local HOST_IP       = environ.get("QUANTA_HOST_IP")

local Metric = singleton()
local prop = property(Metric)
prop:reader("host", nil)            --host
prop:reader("traffics", {})         --traffics
prop:reader("inc_traffics", {})     --inc_traffics
prop:reader("metric_count", 0)      --metric_count

function Metric:__init()
    self.host = luabus.host() or HOST_IP
    if environ.status("QUANTA_METRIC") then
        --添加协议监听
        event_mgr:add_trigger(self, "on_recv_rpc_message")
        event_mgr:add_trigger(self, "on_send_rpc_message")
        event_mgr:add_trigger(self, "on_recv_tcp_message")
        event_mgr:add_trigger(self, "on_send_tcp_message")
        --启动定时器
        update_mgr:attach_second5(self)
        log_debug("[Metric][init] metric startup!")
    end
end

--协议接收
function Metric:on_recv_rpc_message(rpc, recv_len)
    self:collect_traffic("rpc_recv", rpc, recv_len)
end

--协议发送
function Metric:on_send_rpc_message(rpc, send_len)
    self:collect_traffic("rpc_send", rpc, send_len)
end

--协议接收
function Metric:on_recv_tcp_message(message)
    local _, cmd_name = protobuf_mgr:msg_id(message.cmd_id)
    self:collect_traffic("pb_recv", cmd_name, message.len)
end

--协议发送
function Metric:on_send_tcp_message(cmd_id, body, send_len)
    local _, cmd_name = protobuf_mgr:msg_id(cmd_id)
    self:collect_traffic("pb_send", cmd_name, send_len)
end

function Metric:on_second5()
    if self.metric_count > 0 then
        self:send_metric()
    end
end

function Metric:full_traffic(type, event, tar_traffics)
    local traffic = tar_traffics[type]
    if not traffic then
        tar_traffics[type] = {}
        traffic = tar_traffics[type]
    end
    local metric = traffic[event]
    if not metric then
        traffic[event] = { bytes = 0, count = 0 }
    end
end

--收集传输数据
function Metric:collect_traffic(type, event, bytes)
    self.metric_count = self.metric_count + 1
    self:full_traffic(type, event, self.traffics)
    self:full_traffic(type, event, self.inc_traffics)
    local inc_metric = self.inc_traffics[type][event]
    local metric = self.traffics[type][event]
    metric.bytes = metric.bytes + bytes
    metric.count = metric.count + 1
    inc_metric.bytes = metric.bytes
    inc_metric.count = metric.count
end

--上报指标
function Metric:send_metric()
    for type, traffic in pairs(self.inc_traffics) do
        for event, metric in pairs(traffic) do
            self:add_sample("traffic_bytes_total", type, event, metric.bytes)
            self:add_sample("traffic_count_total", type, event, metric.count)
        end
    end
    self.inc_traffics = {}
    self.metric_count = 0
end

function Metric:add_sample(name, type, event, value)
    local labels = {
        { name = "type", value = type },
        { name = "protocol", value = event },
        { name = "host", value = self.host },
        { name = "process", value = quanta.name },
        { name = "service", value = quanta.service_name },
        { name = "__name__", value = name },
    }
    prometheus:add_sample(labels, {{ value = value, timestamp = tnow_ms() }})
end

quanta.metric = Metric()

return Metric
