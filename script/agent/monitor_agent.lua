--monitor_agent.lua
local RpcClient     = import("network/rpc_client.lua")

local tunpack       = table.unpack
local signal_quit   = signal.quit
local env_addr      = environ.addr
local log_err       = logger.err
local log_warn      = logger.warn
local log_info      = logger.info
local qfailed       = quanta.failed

local event_mgr         = quanta.get("event_mgr")
local timer_mgr         = quanta.get("timer_mgr")

local RPC_FAILED        = quanta.enum("KernCode", "RPC_FAILED")
local SECOND_MS         = quanta.enum("PeriodTime", "SECOND_MS")
local RECONNECT_TIME    = quanta.enum("NetwkTime", "RECONNECT_TIME")
local HEARTBEAT_TIME    = quanta.enum("NetwkTime", "HEARTBEAT_TIME")

local MonitorAgent = singleton()
local prop = property(MonitorAgent)
prop:reader("client", nil)
prop:reader("next_connect_time", 0)
prop:reader("ready_watchers", {})
prop:reader("close_watchers", {})

function MonitorAgent:__init()
    --创建连接
    local ip, port = env_addr("QUANTA_MONITOR_ADDR")
    self.client = RpcClient(self, ip, port)
    --心跳定时器
    timer_mgr:register(SECOND_MS, HEARTBEAT_TIME, -1, function()
        self:on_timer()
    end)
    --注册事件
    event_mgr:add_listener(self, "on_quanta_quit")
    event_mgr:add_listener(self, "on_remote_message")
    event_mgr:add_listener(self, "on_service_changed")
end

function MonitorAgent:on_timer()
    local now = quanta.now
    local client = self.client
    if not client:is_alive() then
        if now >= self.next_connect_time then
            self.next_connect_time = now + RECONNECT_TIME
            client:connect()
        end
    else
        if not client:check_lost(now) then
            client:heartbeat()
        end
    end
end

--监听服务断开
function MonitorAgent:watch_service_close(listener, service_name)
    if not self.close_watchers[service_name] then
        self.close_watchers[service_name] = {}
    end
    self.close_watchers[service_name][listener] = true
end

--监听服务注册
function MonitorAgent:watch_service_ready(listener, service_name)
    if not self.ready_watchers[service_name] then
        self.ready_watchers[service_name] = {}
    end
    self.ready_watchers[service_name][listener] = true
end

-- 连接关闭回调
function MonitorAgent:on_socket_error(client, token, err)
    log_info("[MonitorAgent][on_socket_error]: connect lost!")
    -- 设置重连时间
    self.next_connect_time = quanta.now
end

-- 连接成回调
function MonitorAgent:on_socket_connect(client)
    log_info("[MonitorAgent][on_socket_connect]: connect monitor success!")
end

-- 处理Monitor通知退出消息
function MonitorAgent:on_quanta_quit(reason)
    -- 发个退出通知
    event_mgr:notify_trigger("on_quanta_quit", reason)
    -- 关闭会话连接
    timer_mgr:once(SECOND_MS, function()
        log_warn("[MonitorAgent][on_quanta_quit]->service:%s", quanta.name)
        self.client:close()
        signal_quit()
    end)
    return { code = 0 }
end

--执行远程rpc消息
function MonitorAgent:on_remote_message(data, message)
    if not message then
        return {code = RPC_FAILED, msg = "message is nil !"}
    end
    local ok, code, res = tunpack(event_mgr:notify_listener(message, data))
    if not ok or qfailed(code) then
        log_err("[MonitorAgent][on_remote_message] web_rpc faild: ok=%s, ec=%s", ok, code)
        return { code = ok and code or RPC_FAILED, msg = ok and "" or code}
    end
    return { code = 0 , data = res}
end

--服务改变
function MonitorAgent:on_service_changed(service_name, readys, closes)
    local ready_watchers = self.ready_watchers[service_name]
    for listener in pairs(ready_watchers or {}) do
        for id, info in pairs(readys) do
            listener:on_service_ready(id, service_name, info)
        end
    end
    local close_watchers = self.close_watchers[service_name]
    for listener in pairs(close_watchers or {}) do
        for id, info in pairs(closes) do
            listener:on_service_close(id, service_name, info)
        end
    end
end

quanta.monitor = MonitorAgent()

return MonitorAgent
