-- route_test.lua
local log_debug     = logger.debug

local router_mgr    = quanta.get("router_mgr")
local timer_mgr     = quanta.get("timer_mgr")

local RouterTest = singleton()
function RouterTest:__init()
    router_mgr:watch_service_ready(self, "mongo")
    router_mgr:watch_service_close(self, "mongo")

    timer_mgr:once(4000, function()
        local ok, code, res = router_mgr:call_mongo_random("rpc_mongo_find", "default", "test_mongo_1", {}, {_id = 0})
        log_debug("db find ok:%s, code: %s, res = %s", ok, code, res)
    end)
end

function RouterTest:on_service_ready(quanta_id)
    log_debug("on_service_ready quanta_id :%s", quanta_id)
end

function RouterTest:on_service_close(quanta_id)
    log_debug("on_service_close quanta_id :%s", quanta_id)
end

quanta.router_test = RouterTest()

return RouterTest
