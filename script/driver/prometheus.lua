--prometheus.lua
require("luazip")

local tinsert       = table.insert
local log_debug     = logger.debug
local pb_encode     = protobuf.encode
local pb_loadfile   = protobuf.loadfile
local snappy_encode = zip.snappy_encode

local update_mgr    = quanta.get("update_mgr")

local http_client   = quanta.http_client()

local Prometheus = singleton()
local prop = property(Prometheus)
prop:reader("codec", nil)           --codec
prop:reader("headers", {})          --headers
prop:reader("timeseries", {})       --timeseries
prop:reader("prom_url", nil)        --prom_url

function Prometheus:__init()
    self.prom_url = environ.get("QUANTA_PROMETHEUS_URL")
    if self.prom_url then
        --设置压缩编码
       -- self.codec = zipcodec("snappy")
       -- http_client:set_content_codec("application/x-protobuf", self.codec)
        --加载协议
        pb_loadfile("proto/prometheus.pb")
        --设置请求头
        self.headers = {
            ["Content-Encoding"] = "snappy",
            ["Content-Type"] = "application/x-protobuf",
            ["X-Prometheus-Remote-Write-Version"] = "0.1.0"
        }
        --启动定时器
        update_mgr:attach_second5(self)
        log_debug("[Prometheus][init] prometheus url: {}", self.prom_url)
    end
end

function Prometheus:on_second5()
    if #self.timeseries > 0 then
        self:send_prometheus()
    end
end

--添加指标样本
function Prometheus:add_sample(labels, samples)
    if self.prom_url then
        tinsert(self.timeseries, {
            labels = labels,
            samples = samples
        })
    end
end

--上报指标
function Prometheus:send_prometheus()
    local data = { timeseries = self.timeseries }
    log_debug("[Prometheus][send_prometheus] send timeseries={}", self.timeseries)
    local pdata = pb_encode("prometheus.WriteRequest", data)
    local body = snappy_encode(pdata)
    self.timeseries = {}
    local ok, res = http_client:call_post(self.prom_url, body, self.headers)
    if not ok then
        log_debug("[Prometheus][send_prometheus] send prometheus failed, res={}", res)
        return
    end
    log_debug("[Prometheus][send_prometheus] send prometheus success, res={}", res)
end

quanta.prometheus = Prometheus()

return Prometheus
