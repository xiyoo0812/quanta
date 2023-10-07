--webhook.lua
import("network/http_client.lua")

local jencode       = json.encode
local sformat       = string.format

local WEBPATH       = environ.get("QUANTA_WEBHOOK_PATH", "./webhooks/")
local log_dump      = logfeature.dump("webhooks", WEBPATH, true)

local thread_mgr    = quanta.get("thread_mgr")
local http_client   = quanta.get("http_client")

local HOST_IP       = environ.get("QUANTA_HOST_IP")
local HOUR_S        = quanta.enum("PeriodTime", "HOUR_S")

local LIMIT_COUNT   = 3    -- 周期内最大次数

local Webhook = singleton()
local prop = property(Webhook)
prop:reader("mode", nil)            --mode
prop:reader("title", "")            --title
prop:reader("hooks", {})            --webhook通知接口
prop:reader("notify_limit", {})     --控制同样消息的发送频率

function Webhook:__init()
    local mode = environ.get("QUANTA_WEBHOOK_MODE")
    if mode then
        --添加webhook功能
        self.mode = mode
        logger.add_monitor(self)
        self.title = sformat("%s | %s", HOST_IP, quanta.service_name)
        --初始化hooks
        self.hooks.lark_log = environ.get("QUANTA_LARK_URL")
        self.hooks.ding_log = environ.get("QUANTA_DING_URL")
        self.hooks.wechat_log = environ.get("QUANTA_WECHAT_URL")
    end
end

--hook_log
function Webhook:hook_log(url, body)
    if self.mode == "log" then
        log_dump(jencode(body))
        return
    end
    --http输出
    thread_mgr:entry(url, function()
        http_client:call_post(url, body)
    end)
end

--飞书
function Webhook:lark_log(url, context)
    local text = sformat("%s\n %s", self.title, context)
    local body = { msg_type = "text", content = { text = text } }
    self:hook_log(url, body)
end

--企业微信
--at_members: 成员列表，数组，如 at_members = {"wangqing", "@all"}
--at_mobiles: 手机号列表，数组, 如 at_mobiles = {"156xxxx8827", "@all"}
function Webhook:wechat_log(url, context, at_mobiles, at_members)
    local text = sformat("%s\n %s", self.title, context)
    local body = { msgtype = "text", text = { content = text, mentioned_list = at_members, mentioned_mobile_list = at_mobiles } }
    self:hook_log(url, body)
end

--钉钉
--at_all: 是否群at，如 at_all = false/false
--at_mobiles: 手机号列表，数组, 如 at_mobiles = {"189xxxx8325", "156xxxx8827"}
function Webhook:ding_log(url, context, at_mobiles, at_all)
    local text = sformat("%s\n %s", self.title, context)
    local body = { msgtype = "text", text = { content = text }, at = { atMobiles = at_mobiles, isAtAll = at_all } }
    self:hook_log(url, body)
end

--dispatch_log
function Webhook:dispatch_log(content)
    if self.mode then
        local now = quanta.now
        local notify = self.notify_limit[content]
        if not notify then
            notify = { time = now, count = 0 }
            self.notify_limit[content] = notify
        end
        if now - notify.time > HOUR_S then
            notify = { time = now, count = 0 }
        end
        if notify.count > LIMIT_COUNT then
            return
        end
        notify.count = notify.count + 1
        for hook_api, url in pairs(self.hooks) do
            self[hook_api](self, url, content)
        end
    end
end

quanta.webhook = Webhook()

return Webhook
