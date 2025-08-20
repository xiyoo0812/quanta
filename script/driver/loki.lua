--loki.lua
local lformat       = log.format
local tnow_ns       = timer.now_ns
local log_debug     = logger.debug
local tinsert       = table.insert
local sformat       = string.format

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")
local http_client   = quanta.http_client()

local MAX_LOKI_CNT  = 100
local LOG_LEVEL     = log.LOG_LEVEL
local HOST_IP       = environ.get("QUANTA_HOST_IP")

local Loki = singleton()
local prop = property(Loki)
prop:reader("host_ip", nil)         --host_ip
prop:reader("loki_url", nil)        --loki_url
prop:reader("pb_data", {})          --proto_data
prop:reader("log_data", {})         --log_data
prop:reader("loki_count", 0)        --loki_count

function Loki:__init()
    self.host_ip = luabus.host() or HOST_IP
    self.loki_url = environ.get("QUANTA_LOKI_URL")
    if self.loki_url then
        --添加日志监听
        logger.add_monitor(self, LOG_LEVEL.INFO)
        logger.add_monitor(self, LOG_LEVEL.WARN)
        logger.add_monitor(self, LOG_LEVEL.DEBUG)
        logger.add_monitor(self, LOG_LEVEL.ERROR)
        logger.add_monitor(self, LOG_LEVEL.FATAL)
        --添加 协议hook
        event_mgr:register_hook(self, "on_scmd_recv")
        event_mgr:register_hook(self, "on_scmd_send")
        --启动定时器
        update_mgr:attach_second(self)
        log_debug("[Loki][init] loki url: {}", self.loki_url)
    end
end

--协议 recv hook
function Loki:on_scmd_recv(hook, cmd, cmd_body)
    if cmd_body then
        local cmd_id, cmd_name = protobuf_mgr:msg_id(cmd)
        local cmdinfo = lformat("[{:^4}][{:<40}] => {}", 1, cmd_id, cmd_name, cmd_body)
        self:collect_pb(cmdinfo, "recv")
    end
end

--协议 send hook
function Loki:on_scmd_send(hook, cmd, cmd_body)
    local cmd_id, cmd_name = protobuf_mgr:msg_id(cmd)
    local cmdinfo = lformat("[{:^4}][{:<40}] => {}", 1, cmd_id, cmd_name, cmd_body)
    self:collect_pb(cmdinfo, "send")
end

function Loki:on_second()
    if self.loki_count > 0 then
        self:send_loki()
    end
end

--上报日志
function Loki:send_loki()
    local body = { streams = {}}
    for _, logdata in pairs(self.log_data) do
        tinsert(body.streams, logdata)
    end
    for _, pbdata in pairs(self.pb_data) do
        tinsert(body.streams, pbdata)
    end
    self.pb_data = {}
    self.log_data = {}
    self.loki_count = 0
    --下一帧发送
    event_mgr:fire_frame(function()
        http_client:call_post(self.loki_url, body, { ["Content-Type"] = "application/json" })
    end)
end

--collect_log
function Loki:collect_log(content, lvl_name)
    self.loki_count = self.loki_count + 1
    if not self.log_data[lvl_name] then
        self.log_data[lvl_name] = {
            values = { { sformat("%s", tnow_ns()), content } },
            stream = {
                module = "log",
                level = lvl_name,
                pid = quanta.pid,
                host = self.host_ip,
                thread = quanta.thread,
                service_name = quanta.name,
                service = quanta.service_name,
            }
        }
        return
    end
    tinsert(self.log_data[lvl_name].values, { sformat("%s", tnow_ns()), content })
    if self.loki_count > MAX_LOKI_CNT then
        self:send_loki()
    end
end

--collect_pb
function Loki:collect_pb(cmd_body, cmd_type)
    self.loki_count = self.loki_count + 1
    if not self.pb_data[cmd_type] then
        self.pb_data[cmd_type] = {
            values = { { sformat("%s", tnow_ns()), cmd_body } },
            stream = {
                module = "proto",
                type = cmd_type,
                pid = quanta.pid,
                host = self.host_ip,
                thread = quanta.thread,
                service_name = quanta.name,
                service = quanta.service_name,
            }
        }
        return
    end
    tinsert(self.pb_data[cmd_type].values, { sformat("%s", tnow_ns()), cmd_body })
    if self.loki_count > 200 then
        self:send_loki()
    end
end

quanta.loki = Loki()

return Loki
