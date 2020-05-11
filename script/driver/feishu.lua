--feishu.lua
local ljson = require("luacjson")
ljson.encode_sparse_array(true)

local otime         = os.time
local json_encode   = ljson.encode

local event_mgr     = quanta.event_mgr
local router_mgr    = quanta.router_mgr
local thread_mgr    = quanta.thread_mgr

local PeriodTime    = enum("PeriodTime")

local FEISHU_LIMIT_COUNT = 3        -- 周期内最大次数
local ROBOT_URL = "http://open.feishu.cn//open-apis/bot/hook/56b34b9e1c0b4fc0acadef8ebc3894ad"

local Feishu = singleton()
function Feishu:__init()
    --控制同样消息的发送频率
    self.feishu_limit = {}
    --添加事件监听
    event_mgr:add_trigger(self, "on_feishu_log")
end

function Feishu:on_feishu_log(title, log_context)
    local now = otime()
    local log_info = self.feishu_limit[log_context]
    if not log_info then
        log_info = {time = 0, count = 0}
        self.feishu_limit[log_context] = log_info
    end
    if now - log_info.time > PeriodTime.HOUR_S then
        log_info = {time = now, count = 0}
    end
    if log_info.count > FEISHU_LIMIT_COUNT then
        return
    end
    log_info.count = log_info.count + 1
    thread_mgr:fork(function()
        local post_data = json_encode({title = title, text = log_context})
        router_mgr:call_proxy_hash(quanta.id, "rpc_http_post", ROBOT_URL, {}, post_data, {})
    end)
end

quanta.feishu = Feishu()

return Feishu
