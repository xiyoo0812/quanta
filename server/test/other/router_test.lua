-- route_test.lua
local log_debug     = logger.debug

local discover      = quanta.get("discover")
local timer_mgr     = quanta.get("timer_mgr")
local router_mgr    = quanta.get("router_mgr")

local RouterTest = singleton()
function RouterTest:__init()
    discover:watch_service(self, "mongo")

    timer_mgr:once(4000, function()
        local ok, code, res = router_mgr:call_mongo_random("rpc_mongo_find", "default", "test_mongo_1", {}, {_id = 0})
        log_debug("db find ok:{}, code: {}, res = {}", ok, code, res)
    end)
end

function RouterTest:on_service_ready(quanta_id)
    log_debug("on_service_ready quanta_id :{}", quanta_id)
end

function RouterTest:on_service_close(quanta_id)
    log_debug("on_service_close quanta_id :{}", quanta_id)
end

quanta.router_test = RouterTest()

return RouterTest
