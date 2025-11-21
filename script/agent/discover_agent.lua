--discover_agent.lua
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

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local RPC_FAILED    = quanta.enum("KernCode", "RPC_FAILED")

local DiscoverAgent = singleton()
local prop = property(DiscoverAgent)
prop:reader("client", nil)
prop:reader("startup", false)
prop:reader("register", false)
prop:reader("watchers", {})

function DiscoverAgent:__init()
    if environ.status("QUANTA_DISCOVER") then
        --创建连接
        local ip, port = env_addr("QUANTA_DISCOVER_ADDR")
        self.client = RpcClient(self, ip, port)
        --注册事件
        event_mgr:add_listener(self, "rpc_service_ready")
        event_mgr:add_listener(self, "rpc_service_close")
        event_mgr:add_listener(self, "rpc_remote_message")
        event_mgr:add_listener(self, "rpc_service_hotfix")
        event_mgr:add_listener(self, "rpc_server_shutdown")
        event_mgr:add_listener(self, "rpc_set_logger_level")
        event_mgr:add_listener(self, "rpc_show_snapshot")
        --消息
        event_mgr:add_trigger(self, "on_router_connected")
    end
end

function DiscoverAgent:on_router_connected()
    if not self.register then
        self.register = true
        self.client:register()
        for service_name in pairs(self.watchers) do
            if service_name ~= "router" then
                self.client:call("rpc_watch_service", service_name)
            end
        end
    end
    if not self.startup then
        self.startup = true
        event_mgr:fire_frame("on_service_startup")
    end
end

--监听服务
function DiscoverAgent:watch_service(listener, service_name)
    if not self.watchers[service_name] then
        self.watchers[service_name] = {}
    end
    self.watchers[service_name][listener] = true
    if self.register and service_name ~= "router" then
        self.client:call("rpc_watch_service", service_name)
    end
end

-- 连接关闭回调
function DiscoverAgent:on_socket_error(client, token, err)
    log_info("[DiscoverAgent][on_socket_error]: connect lost!")
    self.register = false
end

-- 连接成回调
function DiscoverAgent:on_socket_connect(client)
    log_info("[DiscoverAgent][on_socket_connect]: connect discover success!")
    if quanta.service_name == "router" then
        self.register = true
        client:register()
    end
end

--服务改变
function DiscoverAgent:rpc_service_ready(service_name, readys)
    log_info("[DiscoverAgent][rpc_service_ready]: {}'s node readys {}!", service_name, readys)
    local watchers = self.watchers[service_name]
    for listener in pairs(watchers or {}) do
        for _, info in pairs(readys) do
            if listener.on_service_ready then
                listener:on_service_ready(info.id, service_name, info)
            end
        end
    end
end

function DiscoverAgent:rpc_service_close(id, service_name)
    log_info("[DiscoverAgent][rpc_service_close]: {}'s node id {}!", service_name, id)
    local watchers = self.watchers[service_name]
    for listener in pairs(watchers or {}) do
        if listener.on_service_close then
            listener:on_service_close(id, service_name)
        end
    end
end

-- 停服
function DiscoverAgent:rpc_server_shutdown(reason)
    -- 关闭会话连接
    event_mgr:fire_frame(function()
        log_warn("[DiscoverAgent][rpc_server_shutdown]->service:{}", quanta.name)
        self.client:close()
        signal_quit()
    end)
    return { code = 0 }
end

--执行远程rpc消息
function DiscoverAgent:rpc_remote_message(rpc, data)
    if not rpc then
        return {code = RPC_FAILED, msg = "rpc is nil !"}
    end
    local ok, code, res = tunpack(event_mgr:notify_listener(rpc, data))
    if qfailed(code, ok) then
        log_err("[DiscoverAgent][rpc_remote_message] web_rpc faild: ok={}, ec={}", ok, code)
        return { code = ok and code or RPC_FAILED, msg = ok and "" or code}
    end
    return { code = 0, msg = res}
end

--热更新
function DiscoverAgent:rpc_service_hotfix()
    log_debug("[DiscoverAgent][rpc_service_hotfix]")
    shotfix()
end

function DiscoverAgent:rpc_set_logger_level(level)
    log_debug("[DiscoverAgent][rpc_set_logger_level] level: {}", level)
    log_filter(level)
end

function DiscoverAgent:rpc_show_snapshot()
    local snapshots = {}
    snapshots.object = class_review()
    snapshots.memory = collectgarbage("count")
    snapshots.co_wait = thread_mgr:wait_size()
    snapshots.co_idle = thread_mgr:idle_size()
    log_debug("[DiscoverAgent][rpc_show_snapshot] snapshots: {}", snapshots)
    return SUCCESS, snapshots
end

quanta.discover = DiscoverAgent()

return DiscoverAgent
