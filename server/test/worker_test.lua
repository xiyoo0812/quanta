--worker_test.lua
import("driver/scheduler.lua")

local log_err       = logger.err
local log_debug     = logger.debug

local scheduler     = quanta.get("scheduler")
local timer_mgr     = quanta.get("timer_mgr")

scheduler:setup("quanta")
scheduler:startup("wtest", "wtest")

timer_mgr:loop(2000, function()
    local ok, res1, res2 = scheduler:call("wtest", "test_rpc", 1, 2, 3, 4)
    if not ok then
        log_err("[scheduler][call] call failed: %s", res1)
        return
    end
    log_debug("[scheduler][call] call success: %s, %s", res1, res2)
end)
