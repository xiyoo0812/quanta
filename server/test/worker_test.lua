--worker_test.lua
import("feature/scheduler.lua")

local log_err       = logger.err
local log_debug     = logger.debug

local scheduler     = quanta.get("scheduler")
local event_mgr     = quanta.get("event_mgr")
local timer_mgr     = quanta.get("timer_mgr")

scheduler:startup("wtest", "worker.wtest")

local MaterTest = singleton()

function MaterTest:__init()
    event_mgr:add_listener(self, "test_master_rpc")
end

function MaterTest:test_master_rpc(a, b, c, d)
    log_debug("[MaterTest][test_master_rpc] {}, {}, {}, {}", a, b, c, d)
    return a + b, c + d
end

quanta.master_test = MaterTest()

timer_mgr:loop(2000, function()
    local ok, res1, res2 = scheduler:call("wtest", "test_worker_rpc", 1, 2, 3, 4)
    if not ok then
        log_err("[scheduler][call] test_worker_rpc failed: {}", res1)
        return
    end
    log_debug("[scheduler][call] test_worker_rpc success: {}, {}", res1, res2)
end)
