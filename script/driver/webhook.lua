--webhook.lua
import("network/http_client.lua")

local jencode       = json.encode
local sformat       = string.format
local dgetinfo      = debug.getinfo

local log_dump      = logfeature.dump("webhooks", true)

local thread_mgr    = quanta.get("thread_mgr")
local http_client   = quanta.get("http_client")

local HOST_IP       = environ.get("QUANTA_HOST_IP")
local MINUTE_10_S   = quanta.enum("PeriodTime", "MINUTE_10_S")

local LIMIT_COUNT   = 3    -- 周期内最大次数

local Webhook = singleton()
local prop = property(Webhook)
prop:reader("mode", nil)            --mode
prop:reader("title", "")            --title
prop:reader("hooks", {})            --webhook通知接口
prop:reader("hook_limit", {})     --控制同样消息的发送频率

function Webhook:__init()
    local mode = environ.get("QUANTA_WEBHOOK_MODE")
    if mode ~= "null" then
        --添加webhook功能
        self.mode = mode
        logger.add_monitor(self)
        local domain = luabus.host()
        self.title = sformat("%s | %s", domain or HOST_IP, quanta.service_name)
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
function Webhook:lark_log(url, text)
    self:hook_log(url, { msg_type = "text", content = { text = text } })
end

--企业微信
--at_members: 成员列表，数组，如 at_members = {"wangqing", "@all"}
--at_mobiles: 手机号列表，数组, 如 at_mobs = {"156xxxx8827", "@all"}
function Webhook:wechat_log(url, text, at_mobiles, at_members)
    self:hook_log(url, { msgtype = "text", text = { content = text, mentioned_list = at_members, mentioned_mobile_list = at_mobiles } })
end

--钉钉
--at_all: 是否群at，如 at_all = false/false
--at_mobiles: 手机号列表，数组, 如 at_mobiles = {"189xxxx8325", "156xxxx8827"}
function Webhook:ding_log(url, text, at_mobiles, at_all)
    self:hook_log(url, { msgtype = "text", text = { content = text }, at = { atMobiles = at_mobiles, isAtAll = at_all } })
end

function Webhook:build_hookpos(content)
    local pos = content:find("stack traceback")
    if pos then
        return content:sub(1, pos - 1)
    end
    local info = dgetinfo(4, "Sl")
    return sformat("%s:%s", info.source, info.currentline)
end

--dispatch_log
function Webhook:dispatch_log(content)
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
        self:fire_hook(content, hookinfo.count)
    end
end

function Webhook:fire_hook(content, times)
    local text = sformat("%s (%s times in 10 min)\n%s", self.title, times, content)
    for hook_api, url in pairs(self.hooks) do
        self[hook_api](self, url, text)
    end
end

quanta.webhook = Webhook()

return Webhook
