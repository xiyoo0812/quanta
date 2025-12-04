--webhook.lua

local sformat       = string.format
local dgetinfo      = debug.getinfo

local http_client   = quanta.http_client()
local thread_mgr    = quanta.get("thread_mgr")

local HOST_IP       = environ.get("QUANTA_HOST_IP")
local MINUTE_10_S   = quanta.enum("PeriodTime", "MINUTE_10_S")

local LIMIT_COUNT   = 3    -- 周期内最大次数

local Webhook = singleton()
local prop = property(Webhook)
prop:reader("title", "")        --title
prop:reader("hook_api", nil)    --webhook api
prop:reader("hook_url", nil)    --webhook url
prop:reader("hook_limit", {})   --控制同样消息的发送频率

function Webhook:__init()
    if environ.status("QUANTA_WEBHOOK_URL") then
        self.hook_api = "wechat_log"
        self.hook_url = environ.get("QUANTA_WEBHOOK_URL")
    elseif environ.status("QUANTA_DING_URL") then
        self.hook_api = "ding_log"
        self.hook_url = environ.get("QUANTA_DING_URL")
    elseif environ.status("QUANTA_LARK_URL") then
        self.hook_api = "lark_log"
        self.hook_url = environ.get("QUANTA_LARK_URL")
    end
    if self.hook_url then
        local domain = luabus.host()
        self.title = sformat("%s | %s", domain or HOST_IP, quanta.service_name)
        logger.add_monitor(self)
    end
end

--hook_log
function Webhook:hook_log(body)
    --http输出
    thread_mgr:fork(http_client.call_post, nil, http_client, self.hook_url, body)
end

--飞书
function Webhook:lark_log(text)
    self:hook_log({ msg_type = "text", content = { text = text } })
end

--企业微信
--at_members: 成员列表，数组，如 at_members = {"wangqing", "@all"}
--at_mobiles: 手机号列表，数组, 如 at_mobs = {"156xxxx8827", "@all"}
function Webhook:wechat_log(text, at_mobiles, at_members)
    self:hook_log({ msgtype = "text", text = { content = text, mentioned_list = at_members, mentioned_mobile_list = at_mobiles } })
end

--钉钉
--at_all: 是否群at，如 at_all = false/false
--at_mobiles: 手机号列表，数组, 如 at_mobiles = {"189xxxx8325", "156xxxx8827"}
function Webhook:ding_log(text, at_mobiles, at_all)
    self:hook_log({ msgtype = "text", text = { content = text }, at = { atMobiles = at_mobiles, isAtAll = at_all } })
end

function Webhook:build_hookpos(content)
    local pos = content:find("stack traceback")
    if pos then
        return content:sub(1, pos - 1)
    end
    local info = dgetinfo(4, "Sl")
    return sformat("%s:%s", info.source, info.currentline)
end

--collect_log
function Webhook:collect_log(content, ...)
    if self.mode then
        local now = quanta.now
        local hookpos = self:build_hookpos(content)
        local hookinfo = self.hook_limit[hookpos]
        if not hookinfo then
            hookinfo = { time = now, count = 0 }
            self.hook_limit[hookpos] = hookinfo
        end
        hookinfo.count = hookinfo.count + 1
        if now - hookinfo.time > MINUTE_10_S then
            self:fire_hook(content, hookinfo.count)
            self.hook_limit[hookpos] = { time = now, count = 0 }
            return
        end
        if hookinfo.count > LIMIT_COUNT then
            return
        end
        self:fire_hook(content, hookinfo.count, ...)
    end
end

function Webhook:fire_hook(content, times, ...)
    local text = sformat("%s (%s times in 10 min)\n%s", self.title, times, content)
    self[self.hook_api](self, text, ...)
end

quanta.webhook = Webhook()

return Webhook
