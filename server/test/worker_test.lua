--worker_test.lua

local log_err       = logger.err
local log_info      = logger.info
local log_dump      = logger.dump

local scheduler     = quanta.get("scheduler")
local event_mgr     = quanta.get("event_mgr")
local timer_mgr     = quanta.get("timer_mgr")

scheduler:startup("wtest1", "worker.wtest")

local MaterTest = singleton()

function MaterTest:__init()
    event_mgr:add_listener(self, "test_master_rpc")
    event_mgr:add_listener(self, "test_worker_bc")
end

function MaterTest:test_master_rpc(work_name, a, b, c, d)
    log_info("[MaterTest][test_master_rpc] {} {}, {}, {}, {}", work_name, a, b, c, d)
    return a + b, c + d
end

function MaterTest:test_worker_bc(message)
    log_err("[MaterTest][test_worker_bc] {}", message)
end

quanta.master_test = MaterTest()

timer_mgr:loop(3000, function()
    local ok, res1, res2 = scheduler:call("wtest1", "test_worker_rpc", 1, 2, 3, 4)
    if not ok then
        log_err("[MaterTest][call] test_worker_rpc failed: {}", res1)
        return
    end
    log_dump("[MaterTest][call] test_worker_rpc success: {}, {}", res1, res2)
end)

timer_mgr:once(5000, function()
    scheduler:broadcast("test_worker_bc",  "im master")
end)
