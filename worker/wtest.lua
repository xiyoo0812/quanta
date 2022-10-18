--wtest.lua
import("driver/worker.lua")

local log_debug     = logger.debug

local event_mgr     = quanta.get("event_mgr")

local WorkerTest = class()

function WorkerTest:__init()
    event_mgr:add_listener(self, "test_rpc")
end

function WorkerTest:test_rpc(a, b, c, d)
    log_debug("[WorkerTest][test_rpc] %s, %s, %s, %s", a, b, c, d)
    return a + b, c + d
end

quanta.startup(function()
    quanta.qtest1 = WorkerTest()
end)
