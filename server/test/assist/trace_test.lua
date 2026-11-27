-- trace_test.lua

local log_info      = logger.info

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local discover      = quanta.get("discover")

--等待被调用的最长时间(毫秒)
local WAIT_MS       = 30000
local POLL_MS       = 100

local EXPECT_REMOTE = 1

local TestCase      = import("test/case.lua")
local AssistTrace   = class(TestCase)

------------------------------------------------------------------
-- RPC 应答 handler
------------------------------------------------------------------
function AssistTrace:rpc_trace_remote(client, payload)
    self.remote_count = self.remote_count + 1

    --协议层已把发起端 trace 绑定到当前协程, 这里取到的是"发起端"的上下文
    local cur_trace, cur_span = quanta.extract_trace()
    log_info("[assist][trace][rpc_trace_remote] recv trace={} span={} payload={}",
        cur_trace, cur_span, payload)

    --在续接的 chain 上建子 span(逆序上报, 根 span 结束时整树上送)
    local sub<close> = quanta.traceing("remote_handle")
    sub:add_annotation("handle cross process rpc")
    sub:add_tag("payload", payload or "")

    return cur_trace, cur_span
end

------------------------------------------------------------------
-- discover 观察(确认自身节点已注册就绪)
------------------------------------------------------------------

function AssistTrace:on_service_ready(quanta_id, service_name, info)
    self.readys[service_name] = self.readys[service_name] or {}
    self.readys[service_name][quanta_id] = info
end

------------------------------------------------------------------
-- 工具
------------------------------------------------------------------

function AssistTrace:wait_until(func, timeout_ms)
    local deadline = quanta.clock_ms + (timeout_ms or WAIT_MS)
    while quanta.clock_ms < deadline do
        if func() then
            return true
        end
        thread_mgr:sleep(POLL_MS)
    end
    return false
end

function AssistTrace:run()
    self.remote_count = 0
    self.readys = {}

    --前置检查: 跨进程链路依赖 discover + router
    local discover_on = environ.status("QUANTA_DISCOVER")
    local router_on = environ.status("QUANTA_ROUTER")
    self:report("env discover enabled", discover_on == true, discover_on, true)
    self:report("env router enabled", router_on == true, router_on, true)
    if not discover_on or not router_on then
        log_info("[assist][trace] 服务发现/路由未开启, 仅注册应答 handler, 跳过等待")
        return
    end

    --注册应答 handler, 并观察 test 服务节点(确认自身已注册到 discover)
    event_mgr:listen_event(self, "rpc_trace_remote")
    discover:watch_service(self, "test")

    local self_ready = self:wait_until(function()
        local list = self.readys["test"]
        return list ~= nil and list[quanta.id] ~= nil
    end)
    self:report("assist self registered", self_ready, self.readys["test"] and self.readys["test"][quanta.id],
        "self node info")

    --常驻等待发起端调用
    local called = self:wait_until(function()
        return self.remote_count >= EXPECT_REMOTE
    end)
    self:report("assist served trace rpc", self.remote_count >= EXPECT_REMOTE, self.remote_count, EXPECT_REMOTE)
    if not called then
        log_info("[assist][trace] 等待超时: 未收到发起端的跨进程调用(对端可能未启动)")
    end
    log_info("[assist][trace] done: id={} remote_count={}", quanta.id, self.remote_count)
end

return AssistTrace
