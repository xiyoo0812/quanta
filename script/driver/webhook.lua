--webhook.lua
local ljson         = require("lcjson")

local env_get       = environ.get
local sformat       = string.format
local json_encode   = ljson.encode

local LIMIT_COUNT   = 3    -- 周期内最大次数

local router_mgr    = quanta.get("router_mgr")
local HOUR_S        = quanta.enum("PeriodTime", "HOUR_S")

local Webhook       = singleton()
local prop          = property(Webhook)
prop:reader("url", nil)             --url地址
prop:reader("interface", nil)       --通知接口
prop:reader("notify_limit", {})     --控制同样消息的发送频率
function Webhook:__init()
    if env_get("QUANTA_LARK_URL") then
        return self:setup(env_get("QUANTA_LARK_URL"), "lark_log")
    end
    if env_get("QUANTA_DING_URL") then
        return self:setup(env_get("QUANTA_DING_URL"), "ding_log")
    end
    if env_get("QUANTA_WECHAT_URL") then
        return self:setup(env_get("QUANTA_WECHAT_URL"), "wechat_log")
    end
end

function Webhook:setup(url, interface)
    self.url = url
    self.interface = interface
    logger.set_webhook(self)
end

--飞书
function Webhook:lark_log(title, context)
    local text = sformat("service:%s \n %s \n %s", quanta.name, title, context)
    local body = { msg_type = "text", content = { text = text } }
    router_mgr:send_proxy_hash(quanta.id, "rpc_http_post", self.url, json_encode(body))
end

--企业微信
--at_members: 成员列表，数组，如 at_members = {"wangqing", "@all"}
--at_mobiles: 手机号列表，数组, 如 at_mobiles = {"156xxxx8827", "@all"}
function Webhook:wechat_log(title, context, at_mobiles, at_members)
    local text = sformat("service:%s \n %s \n %s", quanta.name, title, context)
    local body = { msgtype = "text", text = { content = text, mentioned_list = at_members, mentioned_mobile_list = at_mobiles } }
    router_mgr:send_proxy_hash(quanta.id, "rpc_http_post", self.url, json_encode(body))
end

--钉钉
--at_all: 是否群at，如 at_all = false/false
--at_mobiles: 手机号列表，数组, 如 at_mobiles = {"189xxxx8325", "156xxxx8827"}
function Webhook:ding_log(title, context, at_mobiles, at_all)
    local text = sformat("service:%s \n %s \n %s", quanta.name, title, context)
    local body = { msgtype = "text", text = { content = text }, at = { atMobiles = at_mobiles, isAtAll = at_all } }
    router_mgr:send_proxy_hash(quanta.id, "rpc_http_post", self.url, json_encode(body))
end

function Webhook:notify(title, context, ...)
    local interface = self.interface
    if interface then
        local now = quanta.now
        local notify = self.notify_limit[context]
        if not notify then
            notify = { time = now, count = 0 }
            self.notify_limit[context] = notify
        end
        if now - notify.time > HOUR_S then
            notify = { time = now, count = 0 }
        end
        if notify.count > LIMIT_COUNT then
            return
        end
        notify.count = notify.count + 1
        self[interface](self, title, context, ...)
    end
end

quanta.oanotify = Webhook()

return Webhook
