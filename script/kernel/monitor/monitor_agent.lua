--monitor_agent.lua
local RpcClient     = import("kernel/network/rpc_client.lua")

local tunpack       = table.unpack
local signal_quit   = signal.quit
local env_addr      = environ.addr
local log_err       = logger.err
local log_warn      = logger.warn
local log_info      = logger.info
local serialize     = logger.serialize
local check_success = utility.check_success
local check_failed  = utility.check_failed

local KernCode      = enum("KernCode")
local NetwkTime     = enum("NetwkTime")
local PeriodTime    = enum("PeriodTime")

local event_mgr     = quanta.get("event_mgr")
local timer_mgr     = quanta.get("timer_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local MonitorAgent = singleton()
local prop = property(MonitorAgent)
prop:reader("client", nil)
prop:reader("next_connect_time", 0)
function MonitorAgent:__init()
    --创建连接
    local ip, port = env_addr("QUANTA_MONITOR_ADDR")
    self.client = RpcClient(self, ip, port)
    --心跳定时器
    timer_mgr:loop(NetwkTime.HEARTBEAT_TIME, function()
        self:on_timer()
    end)
    --注册事件
    event_mgr:add_listener(self, "on_quanta_quit")
    event_mgr:add_listener(self, "on_remote_message")
    event_mgr:add_listener(self, "on_remote_command")
end

function MonitorAgent:on_timer()
    local now = quanta.now
    local client = self.client
    if not client:is_alive() then
        if now >= self.next_connect_time then
            self.next_connect_time = now + NetwkTime.RECONNECT_TIME
            client:connect()
        end
    else
        if not client:check_lost(now) then
            client:heartbeat()
        end
    end
end

-- 连接关闭回调
function MonitorAgent:on_socket_error(client, err)
    if err == "active-close" then
        -- 主动关闭连接不走重连逻辑
        return
    end
    -- 设置重连时间
    self.next_connect_time = quanta.now
end

-- 连接成回调
function MonitorAgent:on_socket_connect(client)
    log_info("[MonitorAgent][on_socket_connect]: connect monitor success!")
    -- 到monitor注册
    self.client:send("rpc_monitor_register", quanta.id, quanta.service_id, quanta.index, quanta.name)
end

-- 请求服务
function MonitorAgent:service_request(api_name, data)
    local req = {
        data = data,
        id  = quanta.id,
        index = quanta.index,
        service  = quanta.service_id,
    }
    local ok, code, res = self.client:call("rpc_monitor_post", api_name, req)
    if ok and check_success(code) then
        return tunpack(res)
    end
    return false
end

-- 处理Monitor通知退出消息
function MonitorAgent:on_quanta_quit(reason)
    -- 发个退出通知
    event_mgr:notify_trigger("on_quanta_quit", reason)
    -- 关闭会话连接
    thread_mgr:fork(function()
        thread_mgr:sleep(PeriodTime.SECOND_MS)
        self.client:close()
    end)
    timer_mgr:once(PeriodTime.SECOND_MS, function()
        log_warn("[MonitorAgent][on_quanta_quit]->service:%s", quanta.name)
        signal_quit()
    end)
    return { code = 0 }
end

--执行远程rpc消息
function MonitorAgent:on_remote_message(data, message)
    if not message then
        return {code = KernCode.RPC_FAILED, msg = "message is nil !"}
    end
    local ok, code, res = tunpack(event_mgr:notify_listener(message, data))
    if not ok or check_failed(code) then
        log_err("[MonitorAgent][on_remote_message] web_rpc faild: ok=%s, ec=%s", serialize(ok), code)
        return { code = ok and code or KernCode.RPC_FAILED, msg = ok and "" or code}
    end
    return { code = 0 , data = res}
end

quanta.monitor = MonitorAgent()

return MonitorAgent
