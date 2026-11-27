-- rpc_test.lua

local log_info      = logger.info

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local discover      = quanta.get("discover")

--等待被调用的最长时间(毫秒), 需覆盖对端 rpc 用例的就绪等待+若干轮调用
local WAIT_MS       = quanta.enum("PeriodTime", "SECOND_10_MS")
local POLL_MS       = quanta.enum("PeriodTime", "SLOW_MS")

--预期至少收到的调用次数(对端会发: 普通 call、大包 call、send notice)
local EXPECT_ECHO   = 1
local EXPECT_NOTICE = 1

local TestCase      = import("test/case.lua")
local AssistRpc     = class(TestCase)

------------------------------------------------------------------
-- RPC 应答端 handler(必须定义在类上, 供 event_mgr 分发)
------------------------------------------------------------------
--回显: 返回序号与数据长度, 调用方据此校验
function AssistRpc:on_echo(session, n, data)
    local len = type(data) == "table" and #data or 0
    self.echo_count = self.echo_count + 1
    self.last_echo = { n = n, len = len }
    log_info("[assist][on_echo] n={} len={} total={}", n, len, self.echo_count)
    return n, len
end

--无返回值通知
function AssistRpc:on_notice(session, msg)
    self.notice_count = self.notice_count + 1
    self.last_notice = msg
    log_info("[assist][on_notice] msg={} total={}", msg, self.notice_count)
end

------------------------------------------------------------------
-- discover 观察(确认自身节点已注册就绪)
------------------------------------------------------------------

function AssistRpc:on_service_ready(quanta_id, service_name, info)
    self.readys[service_name] = self.readys[service_name] or {}
    self.readys[service_name][quanta_id] = info
    log_info("[assist][on_service_ready] service={} id={}", service_name, quanta_id)
end

------------------------------------------------------------------
-- 工具
------------------------------------------------------------------

function AssistRpc:wait_until(func, timeout_ms)
    local deadline = quanta.clock_ms + (timeout_ms or WAIT_MS)
    while quanta.clock_ms < deadline do
        if func() then
            return true
        end
        thread_mgr:sleep(POLL_MS)
    end
    return false
end

function AssistRpc:run()
    self.echo_count = 0
    self.notice_count = 0
    self.readys = {}

    --前置检查: 跨进程能力依赖 discover + router
    local discover_on = environ.status("QUANTA_DISCOVER")
    local router_on = environ.status("QUANTA_ROUTER")
    self:report("env discover enabled", discover_on == true, discover_on, true)
    self:report("env router enabled", router_on == true, router_on, true)
    if not discover_on or not router_on then
        log_info("[assist] 服务发现/路由未开启, 仅注册应答 handler, 跳过等待")
        return
    end

    --注册应答 handler, 并观察 test 服务节点(确认自身已注册到 discover)
    event_mgr:listen_event(self, "on_echo")
    event_mgr:listen_event(self, "on_notice")
    discover:watch_service(self, "test")

    --自身应在 test 服务节点列表中(discover 已登记本进程)
    local self_ready = self:wait_until(function()
        local list = self.readys["test"]
        return list ~= nil and list[quanta.id] ~= nil
    end)
    self:report("assist self registered", self_ready, self.readys["test"] and self.readys["test"][quanta.id],
        "self node info")

    --常驻等待对端调用(对端可能晚于本进程启动)
    local called = self:wait_until(function()
        return self.echo_count >= EXPECT_ECHO and self.notice_count >= EXPECT_NOTICE
    end)

    self:report("assist served echo", self.echo_count >= EXPECT_ECHO, self.echo_count, EXPECT_ECHO)
    self:report("assist served notice", self.notice_count >= EXPECT_NOTICE, self.notice_count, EXPECT_NOTICE)
    if not called then
        log_info("[assist] 等待超时: 未收到预期的对端调用(对端可能未启动)")
    end
    log_info("[assist] done: id={} echo={} notice={} last_echo={}",
        quanta.id, self.echo_count, self.notice_count, self.last_echo)
end

return AssistRpc
