--wtest.lua
import("feature/worker.lua")

local log_err       = logger.err
local log_debug     = logger.debug

local event_mgr     = quanta.get("event_mgr")

local WorkerTest = class()

function WorkerTest:__init()
    event_mgr:add_listener(self, "test_worker_rpc")
end

function WorkerTest:test_worker_rpc(a, b, c, d)
    log_debug("[WorkerTest][test_worker_rpc] {}, {}, {}, {}", a, b, c, d)
    return a + b, c + d
end

quanta.startup(function()
    quanta.qtest1 = WorkerTest()
    local timer_mgr = quanta.get("timer_mgr")
    timer_mgr:loop(2000, function()
        local ok, res1, res2 = quanta.call_master("test_master_rpc", 1, 2, 3, 4)
        if not ok then
            log_err("[worker][call_master] test_master_rpc failed: {}", res1)
            return
        end
        log_debug("[worker][call_master] test_master_rpc success: {}, {}", res1, res2)
    end)
end)
