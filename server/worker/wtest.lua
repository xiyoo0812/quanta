--wtest.lua
import("kernel.lua")

local log_err       = logger.err
local log_info      = logger.info
local log_dump      = logger.dump

local WorkerTest = class()

function WorkerTest:__init()
    local scheduler = quanta.get("scheduler")
    local event_mgr = quanta.get("event_mgr")
    event_mgr:add_listener(self, "test_worker_rpc")
    event_mgr:add_listener(self, "test_worker_bc")
    -- 启动wtest2线程
    scheduler:startup("wtest2", "worker.wtest")
end

function WorkerTest:test_worker_rpc(a, b, c, d)
    log_info("[WorkerTest][test_worker_rpc] {}, {}, {}, {}", a, b, c, d)
    return a + b, c + d
end

function WorkerTest:test_worker_bc(message)
    log_err("[WorkerTest][test_worker_bc] {}", message)
end

quanta.startup(function()
    quanta.qtest1 = WorkerTest()
    local timer_mgr = quanta.get("timer_mgr")
    local scheduler = quanta.get("scheduler")
    timer_mgr:loop(3000, function()
        local ok, res1, res2 = scheduler:call("master", "test_master_rpc", scheduler:thread_name(), 4, 3, 2, 1)
        if not ok then
            log_err("[WorkerTest][call master] test_master_rpc failed: {}", res1)
            return
        end
        log_dump("[WorkerTest][call master] test_master_rpc success: {}, {}", res1, res2)
    end)
    timer_mgr:once(6000, function()
        scheduler:broadcast("test_worker_bc",  string.format("im worker: %s", scheduler:thread_name()))
    end)
end)
