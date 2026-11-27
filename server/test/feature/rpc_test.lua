-- rpc_test.lua

local log_info      = logger.info
local log_err       = logger.err
local sformat       = string.format
local name2sid      = service.name2sid
local make_sid      = service.make_sid

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local router_mgr    = quanta.get("router_mgr")
local discover      = quanta.get("discover")

local SERV_TEST     = name2sid("test")

--等待异步回调的超时(毫秒)
local WAIT_MS       = quanta.enum("PeriodTime", "SECOND_10_MS")
local POLL_MS       = quanta.enum("PeriodTime", "SLOW_MS")

local TestCase      = import("test/case.lua")
local RpcTest       = class(TestCase)

--回显: 返回序号与数据长度, 调用方据此校验
function RpcTest:on_echo(session, n, data)
    local len = type(data) == "table" and #data or 0
    self.echo_count = (self.echo_count or 0) + 1
    log_info("[rpc][on_echo] from={} n={} len={}", quanta.name, n, len)
    return n, len
end

------------------------------------------------------------------
-- discover 观察回调
------------------------------------------------------------------

--节点就绪: 记录各服务已就绪的节点 id
function RpcTest:on_service_ready(quanta_id, service_name, info)
    self.readys = self.readys or {}
    self.readys[service_name] = self.readys[service_name] or {}
    self.readys[service_name][quanta_id] = info
    log_info("[rpc][on_service_ready] service={} id={}", service_name, quanta_id)
end

--节点关闭
function RpcTest:on_service_close(quanta_id, service_name, info)
    self.closes = self.closes or {}
    self.closes[#self.closes + 1] = { id = quanta_id, service = service_name }
    log_info("[rpc][on_service_close] service={} id={}", service_name, quanta_id)
end

------------------------------------------------------------------
-- 工具
------------------------------------------------------------------

--轮询等待条件成立
function RpcTest:wait_until(func, timeout_ms, poll_ms)
    local deadline = quanta.clock_ms + (timeout_ms or WAIT_MS)
    while quanta.clock_ms < deadline do
        if func() then
            return true
        end
        thread_mgr:sleep(poll_ms or POLL_MS)
    end
    return false
end

--取另一个 test 进程的 id(本机 index 为 1/2, 对端取另一个)
function RpcTest:peer_test_id()
    local peer_index = (quanta.index == 1) and 2 or 1
    return make_sid(SERV_TEST, peer_index)
end

function RpcTest:run()
    self.echo_count = 0
    self.readys = {}
    self.closes = {}

    ------------------------------------------------------------------
    -- 前置检查: 本用例依赖 discover + router(多进程环境)
    -- 未开启时只报一条前置失败并跳过后续, 避免大量无谓等待
    ------------------------------------------------------------------
    local router_on = environ.status("QUANTA_ROUTER")
    local discover_on = environ.status("QUANTA_DISCOVER")
    self:report("env discover enabled", discover_on == true, discover_on, true)
    self:report("env router enabled", router_on == true, router_on, true)
    if not discover_on or not router_on then
        log_err("[rpc] 服务发现/路由未开启, 跳过 rpc 用例(需多进程环境运行)")
        return
    end

    --注册 RPC 应答与 discover 观察
    event_mgr:listen_event(self, "on_echo")
    discover:watch_service(self, "router")
    discover:watch_service(self, "test")
    ------------------------------------------------------------------
    -- A. 本机信息
    ------------------------------------------------------------------
    self:report("self id", quanta.id == make_sid(SERV_TEST, quanta.index),
        quanta.id, make_sid(SERV_TEST, quanta.index))
    self:report("self name", quanta.name == sformat("test-%d", quanta.index), quanta.name, "test-N")

    ------------------------------------------------------------------
    -- B. discover: 等待 router / test 节点就绪
    ------------------------------------------------------------------
    local router_ready = self:wait_until(function()
        local list = self.readys["router"]
        return list ~= nil and next(list) ~= nil
    end)
    self:report("discover router ready", router_ready, self.readys["router"], "not nil")

    local test_ready = self:wait_until(function()
        local list = self.readys["test"]
        return list ~= nil and list[quanta.id] ~= nil
    end)
    self:report("discover self in test", test_ready, self.readys["test"] and self.readys["test"][quanta.id],
        "self node info")

    ------------------------------------------------------------------
    -- C. router 能力
    ------------------------------------------------------------------
    self:report("router available", router_mgr:available() == true, router_mgr:available(), true)

    local ok_local, res_n, res_len = router_mgr:call_target(quanta.id, "on_echo", 101, { 1, 2, 3 })
    self:report("local rpc call", ok_local == true and res_n == 101 and res_len == 3,
        { ok_local, res_n, res_len }, { true, 101, 3 })

    ------------------------------------------------------------------
    -- D. 跨 test 进程 RPC: 等对端节点就绪后互调
    ------------------------------------------------------------------
    local peer_id = self:peer_test_id()
    local peer_ready = self:wait_until(function()
        local list = self.readys["test"]
        return list ~= nil and list[peer_id] ~= nil
    end)
    self:report("discover peer test ready", peer_ready, peer_id, "peer node info")
    if not peer_ready then
        --对端未启动时, 跨进程用例无法进行, 明确记录失败原因
        self:report("cross test rpc call", false, "peer test process not ready", "peer node info")
        return
    end

    local ok_peer = self:wait_until(function()
        local ok, n = router_mgr:call_target(peer_id, "on_echo", 202, { 1, 2, 3, 4, 5 })
        if ok == true and n == 202 then
            self.last_peer_ok = true
            return true
        end
        self.last_peer_err = n
        return false
    end)
    self:report("cross test rpc call", ok_peer == true, self.last_peer_err or "retry", "ok")

    --send_target: 单向通知到对端(不等待应答), 由对端 assist 用例的 on_notice 接收
    local ok_send = router_mgr:send_target(peer_id, "on_notice", sformat("hello-from-%d", quanta.index))
    self:report("cross test send notice", ok_send ~= false, ok_send, true)

    ------------------------------------------------------------------
    -- E. 大数据量 RPC(61*1024 个整数, 校验序列化/分片)
    ------------------------------------------------------------------
    local big = {}
    for i = 1, 61 * 1024 do
        big[i] = i
    end
    local ok_big, big_n, big_len = router_mgr:call_target(peer_id, "on_echo", 303, big)
    self:report("cross test big rpc", ok_big == true and big_n == 303 and big_len == #big,
        { ok_big, big_n, big_len }, { true, 303, #big })

    log_info("[rpc] done: index={} id={} peer={} echo_count={}",
        quanta.index, quanta.id, peer_id, self.echo_count)
end

return RpcTest
