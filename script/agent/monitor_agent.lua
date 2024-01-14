--monitor_agent.lua
local RpcClient     = import("network/rpc_client.lua")

local tunpack       = table.unpack
local signal_quit   = signal.quit
local env_addr      = environ.addr
local log_err       = logger.err
local log_warn      = logger.warn
local log_info      = logger.info
local log_debug     = logger.debug

local log_filter    = logger.filter
local qfailed       = quanta.failed
local shotfix       = signal.hotfix

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local ROUTER        = quanta.enum("QuantaMode", "ROUTER")
local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local RPC_FAILED    = quanta.enum("KernCode", "RPC_FAILED")

local MonitorAgent = singleton()
local prop = property(MonitorAgent)
prop:reader("client", nil)
prop:reader("startup", false)
prop:reader("register", false)
prop:reader("ready_watchers", {})
prop:reader("close_watchers", {})

function MonitorAgent:__init()
    --创建连接
    local ip, port = env_addr("QUANTA_MONITOR_ADDR")
    self.client = RpcClient(self, ip, port)
    --注册事件
    event_mgr:add_listener(self, "rpc_remote_message")
    event_mgr:add_listener(self, "rpc_service_changed")
    event_mgr:add_listener(self, "rpc_service_hotfix")
    event_mgr:add_listener(self, "rpc_server_shutdown")
    event_mgr:add_listener(self, "rpc_set_logger_level")
    event_mgr:add_listener(self, "rpc_show_snapshot")
    --消息
    event_mgr:add_trigger(self, "on_router_connected")
end

function MonitorAgent:on_router_connected()
    if not self.register then
        self.register = true
        self.client:register()
    end
    if not self.startup then
        self.startup = true
        event_mgr:fire_frame("on_service_startup")
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
    self.register = false
end

-- 连接成回调
function MonitorAgent:on_socket_connect(client)
    log_info("[MonitorAgent][on_socket_connect]: connect monitor success!")
    if quanta.mode == ROUTER then
        client:register()
    end
end

-- 停服
function MonitorAgent:rpc_server_shutdown(reason)
    -- 关闭会话连接
    event_mgr:fire_frame(function()
        log_warn("[MonitorAgent][rpc_server_shutdown]->service:{}", quanta.name)
        self.client:close()
        signal_quit()
    end)
    return { code = 0 }
end

--执行远程rpc消息
function MonitorAgent:rpc_remote_message(message, data)
    if not message then
        return {code = RPC_FAILED, msg = "message is nil !"}
    end
    local ok, code, res = tunpack(event_mgr:notify_listener(message, data))
    if qfailed(code, ok) then
        log_err("[MonitorAgent][rpc_remote_message] web_rpc faild: ok={}, ec={}", ok, code)
        return { code = ok and code or RPC_FAILED, msg = ok and "" or code}
    end
    return { code = 0, msg = res}
end

--服务改变
function MonitorAgent:rpc_service_changed(service_name, readys, closes)
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

--热更新
function MonitorAgent:rpc_service_hotfix()
    log_debug("[MonitorAgent][rpc_service_hotfix]")
    shotfix()
end

function MonitorAgent:rpc_set_logger_level(level)
    log_debug("[MonitorAgent][rpc_set_logger_level] level: {}", level)
    log_filter(level)
end

function MonitorAgent:rpc_show_snapshot()
    local snapshots = {}
    snapshots.object = class_review()
    snapshots.memory = collectgarbage("count")
    snapshots.co_wait = thread_mgr:wait_size()
    snapshots.co_idle = thread_mgr:idle_size()
    log_debug("[MonitorAgent][rpc_show_snapshot] snapshots: {}", snapshots)
    return SUCCESS, snapshots
end

quanta.monitor = MonitorAgent()

return MonitorAgent
