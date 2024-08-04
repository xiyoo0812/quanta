--loki.lua
import("network/http_client.lua")

local tnow_ns       = timer.now_ns
local log_debug     = logger.debug
local tinsert       = table.insert
local sformat       = string.format

local update_mgr    = quanta.get("update_mgr")
local http_client   = quanta.get("http_client")

local LOG_LEVEL     = log.LOG_LEVEL
local HOST_IP       = environ.get("QUANTA_HOST_IP")

local Loki = singleton()
local prop = property(Loki)
prop:reader("host_ip", nil)         --host_ip
prop:reader("loki_url", nil)        --loki_url
prop:reader("loki_data", {})        --loki_data
prop:reader("log_count", 0)         --log_count

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
        --启动定时器
        update_mgr:attach_second(self)
        log_debug("[Loki][init] loki url: {}", self.loki_url)
    end
end

--上报日志
function Loki:on_second()
    local body = { streams = {}}
    for _, logdata in pairs(self.loki_data) do
        table.insert(body.streams, logdata)
    end
    if self.log_count > 0 then
        http_client:call_post(self.loki_url, body, { ["Content-Type"] = "application/json" })
        self.loki_data = {}
        self.log_count = 0
    end
end

--dispatch_log
function Loki:dispatch_log(content, lvl_name)
    self.log_count = self.log_count + 1
    if not self.loki_data[lvl_name] then
        self.loki_data[lvl_name] = {
            values = { { sformat("%s", tnow_ns()), content } },
            stream = {
                level = lvl_name,
                pid = quanta.pid,
                name = quanta.name,
                host = self.host_ip,
                thread = quanta.title,
                service = quanta.service_name,
            }
        }
        return
    end
    tinsert(self.loki_data[lvl_name].values, { sformat("%s", tnow_ns()), content })
end

quanta.Loki = Loki()

return Loki
