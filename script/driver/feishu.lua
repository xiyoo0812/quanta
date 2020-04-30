--feishu.lua
local ljson = require("luacjson")
ljson.encode_sparse_array(true)

local otime         = os.time
local json_encode   = ljson.encode
local env_status    = environ.status
local sname2sid     = service.name2sid

local listener      = quanta.listener
local timer_mgr     = quanta.timer_mgr
local router_mgr    = quanta.router_mgr
local thread_mgr    = quanta.thread_mgr

local FEISHU_LIMIT_COUNT = 3        -- 周期内最大次数
local FEISHU_LIMIT_CYCLE = 60 * 60  -- 频率控制周期

local ROBOT_URL = "http://open.feishu.cn//open-apis/bot/hook/56b34b9e1c0b4fc0acadef8ebc3894ad"

local Feishu = singleton()

function Feishu:__init()
    --控制同样消息的发送频率
    self.feishu_limit = {}
    self.service_id = sname2sid("dbsvr")
    --添加事件监听
    listener:add_trigger(self, "on_feishu_log")
end

function Feishu:on_feishu_log(title, log_context)
    if not env_status("QUANTA_FEISHU") then
        return
    end
    local now = otime()
    local log_info = self.feishu_limit[log_context]
    if not log_info then
        log_info = {time = 0, count = 0}
        self.feishu_limit[body] = log_info
    end
    if now - log_info.time > FEISHU_LIMIT_CYCLE then
        log_info = {time = now, count = 0}
    end
    if log_info.count > FEISHU_LIMIT_COUNT then
        return
    end
    log_info.count = log_info.count + 1
    thread_mgr:fork(function()
        local post_data = json_encode({title = title, text = log_context})
        router_mgr:call_hash(self.service_id, ROBOT_URL, "rpc_http_post", ROBOT_URL, {}, post_data, {})
    end)
end

hive.feishu = Feishu()

return Feishu
