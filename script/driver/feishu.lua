--feishu.lua
local ljson = require("luacjson")
ljson.encode_sparse_array(true)

local otime         = os.time
local json_encode   = ljson.encode
local env_get       = environ.get

local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local PeriodTime    = enum("PeriodTime")

local FEISHU_LIMIT_COUNT = 3    -- 周期内最大次数

local Feishu = singleton()
local prop = property(Feishu)
prop:accessor("url", nil)           --飞书url地址
prop:accessor("feishu_limit", {})   --控制同样消息的发送频率
function Feishu:__init()
    local url = env_get("QUANTA_FEISHU_URL")
    --添加事件监听
    if url and #url > 0 then
        event_mgr:add_trigger(self, "on_feishu_log")
        self.url = url
    end
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
        router_mgr:call_proxy_hash(quanta.id, "rpc_http_post", self.url, {}, post_data)
    end)
end

quanta.feishu = Feishu()

return Feishu
