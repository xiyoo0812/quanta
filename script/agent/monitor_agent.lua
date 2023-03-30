--monitor_agent.lua
local RpcClient     = import("network/rpc_client.lua")

local odate         = os.date
local tunpack       = table.unpack
local signal_quit   = signal.quit
local env_addr      = environ.addr
local log_err       = logger.err
local log_warn      = logger.warn
local log_info      = logger.info
local log_debug     = logger.debug

local log_filter    = logger.filter
local qfailed       = quanta.failed
local sfind         = string.find
local sformat       = string.format
local ssplit        = qstring.split

local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local thread_mgr        = quanta.get("thread_mgr")

local PULL_CNT_MAX      = 10
local SUCCESS           = quanta.enum("KernCode", "SUCCESS")
local RPC_FAILED        = quanta.enum("KernCode", "RPC_FAILED")
local RECONNECT_TIME    = quanta.enum("NetwkTime", "RECONNECT_TIME")

local MonitorAgent = singleton()
local prop = property(MonitorAgent)
prop:reader("client", nil)
prop:reader("sessions", {})
prop:reader("ready_watchers", {})
prop:reader("close_watchers", {})

function MonitorAgent:__init()
    --创建连接
    local ip, port = env_addr("QUANTA_MONITOR_ADDR")
    self.client = RpcClient(self, ip, port)
    --注册事件
    event_mgr:add_listener(self, "rpc_remote_log")
    event_mgr:add_listener(self, "rpc_remote_message")
    event_mgr:add_listener(self, "rpc_service_changed")
    event_mgr:add_listener(self, "rpc_service_hotfix")
    event_mgr:add_listener(self, "rpc_server_shutdown")
    event_mgr:add_listener(self, "rpc_set_logger_level")
    --心跳定时器
    update_mgr:attach_second5(self)
end

function MonitorAgent:on_second5()
    local now = quanta.now
    for session_id, session in pairs(self.sessions) do
        if now - session.active_time > RECONNECT_TIME then
            log_debug("[RemoteLog][on_timer]->overdue->session_id:%s", session_id)
            self:close_session(session_id)
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
end

-- 连接成回调
function MonitorAgent:on_socket_connect(client)
    log_info("[MonitorAgent][on_socket_connect]: connect monitor success!")
end

-- 停服
function MonitorAgent:rpc_server_shutdown(reason)
    -- 关闭会话连接
    update_mgr:attach_next(function()
        log_warn("[MonitorAgent][rpc_server_shutdown]->service:%s", quanta.name)
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
        log_err("[MonitorAgent][rpc_remote_message] web_rpc faild: ok=%s, ec=%s", ok, code)
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
    event_mgr:notify_trigger("on_service_hotfix")
end

function MonitorAgent:rpc_set_logger_level(level)
    log_debug("[MonitorAgent][rpc_set_logger_level] level: %s", level)
    log_filter(level)
end

--日志监控
----------------------------------------------
function MonitorAgent:open_session(data)
    local session_id = data.session_id
    if not session_id then
        session_id = thread_mgr:build_session_id()
    end
    local session = self.sessions[session_id]
    if not session then
        session = {
            pull_index  = 0,
            cache_logs  = {},
            filters     = {},
            session_id  = session_id,
        }
        self.sessions[session_id] = session
    end
    if data.filters then
        session.filters = ssplit(data.filters, " ")
    end
    session.active_time = quanta.now
    return session
end

function MonitorAgent:close_session(session_id)
    self.sessions[session_id] = nil
    if not next(self.sessions) then
        logger.remove_monitor(self)
    end
end

function MonitorAgent:dispatch_log(content, lvl_name)
    for _, session in pairs(self.sessions) do
        local cache = false
        if #session.filters == 0 then
            cache = true
            goto docache
        end
        for _, filter in pairs(session.filters) do
            if sfind(content, filter) then
                cache = true
                goto docache
            end
        end
        :: docache ::
        if cache then
            local cache_logs = session.cache_logs
            cache_logs[#cache_logs + 1] = sformat("[%s][%s]%s", odate("%Y-%m-%d %H:%M:%S"), lvl_name, content)
        end
    end
end

function MonitorAgent:rpc_remote_log(data)
    if not next(self.sessions) then
        logger.add_monitor(self)
    end
    local show_logs = {}
    local session = self:open_session(data)
    local log_size = #(session.cache_logs)
    local log_cnt = log_size - session.pull_index
    if log_cnt > 0 then
        local count = log_cnt > PULL_CNT_MAX and PULL_CNT_MAX or log_cnt
        for idx = 1, count do
            show_logs[#show_logs + 1] = session.cache_logs[session.pull_index + idx]
        end
        session.pull_index = session.pull_index + count
        if session.pull_index >= log_size then
            session.cache_logs = {}
            session.pull_index = 0
        end
    end
    return SUCCESS, { logs = show_logs, session_id = session.session_id }
end

quanta.monitor = MonitorAgent()

return MonitorAgent
