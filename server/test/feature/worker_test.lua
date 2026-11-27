-- worker_test.lua

local log_info      = logger.info

local scheduler     = quanta.get("scheduler")
local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local TestCase      = import("test/case.lua")
local WorkerTest    = class(TestCase)

--master 侧 handler: worker 回调 master 时调用(必须在 startup 前定义)
function WorkerTest:test_master_rpc(work_name, a, b, c, d)
    self.master_calls = (self.master_calls or 0) + 1
    log_info("[worker][master_rpc] {} {} {} {} {}", work_name, a, b, c, d)
    return a + b, c + d
end

function WorkerTest:test_worker_bc(message)
    self.bc_count = (self.bc_count or 0) + 1
    log_info("[worker][broadcast] {}", message)
end

function WorkerTest:run()
    self.master_calls = 0
    self.bc_count = 0

    --注册 master 侧事件(worker 会回 call / broadcast)
    event_mgr:listen_event(self, "test_master_rpc")
    event_mgr:listen_event(self, "test_worker_bc")

    --启动 wtest worker 线程
    scheduler:startup("wtest1", "worker.wtest")
    self:report("worker startup", true, true, true)

    --等 worker 就绪后调用其 RPC
    thread_mgr:sleep(500)
    local ok, res1, res2 = scheduler:call("wtest1", "test_worker_rpc", 1, 2, 3, 4)
    self:report("master call worker", ok == true and res1 == 3 and res2 == 7,
        { ok, res1, res2 }, { false, res1 })

    --广播到 worker
    scheduler:broadcast("test_worker_bc", "hello from master")

    --等待 worker 回调 master()
    for _ = 1, 20 do
        thread_mgr:sleep(100)
    end
    self:report("master broadcast", self.bc_count > 0, self.bc_count, ">0")
    self:report("worker call master", self.master_calls > 0, self.master_calls, ">0")

    log_info("[worker] master_calls={}, bc={}", self.master_calls, self.bc_count)
end

return WorkerTest
