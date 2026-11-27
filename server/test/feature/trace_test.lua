-- trace_test.lua

local log_info      = logger.info
local log_debug     = logger.debug

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local router_mgr    = quanta.get("router_mgr")
local discover      = quanta.get("discover")

--服务id(见 server/config/service_cfg.lua)
local SERVICE_TEST  = 31

--等待异步回调的超时(毫秒)
local WAIT_MS       = 10000
local POLL_MS       = 100

local TestCase      = import("test/case.lua")
local TraceTest     = class(TestCase)

--回显 trace 上下文: 返回本端当前 (trace_id, span_id), 调用方可校验链路是否贯通
function TraceTest:rpc_trace_echo(session)
    local cur_trace, cur_span = quanta.extract_trace()
    log_info("[trace][server][rpc_trace_echo] cur trace={} span={}", cur_trace, cur_span)
    return cur_trace, cur_span
end

------------------------------------------------------------------
-- discover 观察(等待对端节点就绪)
------------------------------------------------------------------

function TraceTest:on_service_ready(quanta_id, service_name, info)
    self.readys[service_name] = self.readys[service_name] or {}
    self.readys[service_name][quanta_id] = info
end

------------------------------------------------------------------
-- 工具
------------------------------------------------------------------

function TraceTest:wait_until(func, timeout_ms)
    local deadline = quanta.clock_ms + (timeout_ms or WAIT_MS)
    while quanta.clock_ms < deadline do
        if func() then
            return true
        end
        thread_mgr:sleep(POLL_MS)
    end
    return false
end

--对端 test 进程 id(index=1 的对端是 2)
function TraceTest:peer_test_id()
    return service.make_sid(SERVICE_TEST, 2)
end

------------------------------------------------------------------
-- 同进程嵌套链路: func1 -> func2 -> func3
-- span 均为局部变量 + <close>, 离开作用域时逆序上报, 根 span 结束时整树上送
------------------------------------------------------------------

function TraceTest:trace_func3()
    local span<close> = quanta.traceing("trace_func3")
    span:add_annotation("enter trace_func3")
    span:add_tag("layer", 3)
    log_debug("[trace][func3] trace_id={}", quanta.trace_id())
    self.span_seq[#self.span_seq + 1] = "trace_func3"
end

function TraceTest:trace_func2()
    local span<close> = quanta.traceing("trace_func2")
    span:add_annotation("enter trace_func2")
    span:add_tag("layer", 2)
    log_debug("[trace][func2] trace_id={}", quanta.trace_id())
    self.span_seq[#self.span_seq + 1] = "trace_func2"
    self:trace_func3()
end

function TraceTest:trace_func1()
    local span<close> = quanta.traceing("trace_func1")
    span:add_annotation("enter trace_func1")
    span:add_tag("layer", 1)
    self.root_trace_id = quanta.trace_id()
    log_debug("[trace][func1] trace_id={}", self.root_trace_id)
    self.span_seq[#self.span_seq + 1] = "trace_func1"
    self:trace_func2()
end

function TraceTest:run()
    self.span_seq = {}
    self.readys = {}

    --前置检查: 跨进程链路依赖 discover + router
    local discover_on = environ.status("QUANTA_DISCOVER")
    local router_on = environ.status("QUANTA_ROUTER")
    self:report("env discover enabled", discover_on == true, discover_on, true)
    self:report("env router enabled", router_on == true, router_on, true)
    if not discover_on or not router_on then
        log_info("[trace] 服务发现/路由未开启, 跳过 trace 用例")
        return
    end

    event_mgr:listen_event(self, "rpc_trace_echo")
    discover:watch_service(self, "test")

    ------------------------------------------------------------------
    -- A. 同进程嵌套链路
    -- 注: 本用例 run 已在 thread_mgr 的协程中执行, traceing 会自动建根 chain
    ------------------------------------------------------------------
    self:trace_func1()

    self:report("nested span count", #self.span_seq == 3, self.span_seq,
        { "trace_func1", "trace_func2", "trace_func3" })
    self:report("nested span order", self.span_seq[1] == "trace_func1" and self.span_seq[3] == "trace_func3",
        self.span_seq, "func1 first, func3 last")
    self:report("root trace id not empty", type(self.root_trace_id) == "string" and #self.root_trace_id > 0,
        self.root_trace_id, "non-empty hex")

    --根 span 结束后 chain 已 output 并从协程摘除, 新 traceing 应该是新 trace
    thread_mgr:sleep(50)
    local new_trace = quanta.trace_id()
    self:report("trace reset after root", new_trace == "", new_trace, "")

    ------------------------------------------------------------------
    -- B. 本地 RPC(自己调自己): 走 event 本地分发, 同一协程, trace 上下文一致
    ------------------------------------------------------------------
    local ok_local, l_trace, l_span = router_mgr:call_target(quanta.id, "rpc_trace_echo")
    self:report("local rpc ok", ok_local == true, ok_local, true)
    --本地调用不新建 trace, 处理侧拿到的是调用方当前 chain(根结束后为空, 故为 0)
    self:report("local rpc trace empty", l_trace == 0 and l_span == 0, { l_trace, l_span }, { 0, 0 })

    ------------------------------------------------------------------
    -- C. 跨进程链路: trace 由 RPC 协议层自动透传
    ------------------------------------------------------------------
    local peer_id = self:peer_test_id()
    local peer_ready = self:wait_until(function()
        local list = self.readys["test"]
        return list ~= nil and list[peer_id] ~= nil
    end)
    self:report("discover peer ready", peer_ready, peer_id, "peer node info")
    if not peer_ready then
        self:report("cross trace chain", false, "peer test process not ready", "peer node info")
        return
    end

    --发起端建根 span 后再发 RPC: 协议层会自动把当前 (trace_id, span_id) 写进协议头
    local span<close> = quanta.traceing("cross_rpc")
    span:add_annotation("cross process rpc begin")
    span:add_tag("peer", peer_id)
    local trace_id, span_id = quanta.extract_trace()
    self:report("extract trace context", trace_id > 0 and span_id > 0, { trace_id, span_id }, ">0")

    --对端在 handler 里直接 traceing, 会挂在发起端 chain 下(自动 resume_trace + bind)
    --返回对端看到的 (trace_id, parent_span_id), 用于校验链路贯通
    local ok_c, r_trace, r_span = router_mgr:call_target(peer_id, "rpc_trace_remote", "cross_payload")
    self:report("cross rpc ok", ok_c == true, ok_c, true)
    --对端 trace_id 必须与发起端一致(同一条链路)
    self:report("cross rpc trace matched", ok_c == true and r_trace == trace_id,
        { r_trace, trace_id }, "equal")
    --对端的父 span 必须是发起端 cross_rpc 的 span_id(父子关系成立)
    self:report("cross rpc parent matched", ok_c == true and r_span == span_id,
        { r_span, span_id }, "equal")

    log_info("[trace] done: root={} cross={} peer={}", self.root_trace_id, trace_id, peer_id)
end

return TraceTest
