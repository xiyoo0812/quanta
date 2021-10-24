-- route_test.lua
local log_debug     = logger.debug

local router_mgr    = quanta.get("router_mgr")
local timer_mgr     = quanta.get("timer_mgr")

local RouterTest = singleton()
function RouterTest:__init()
end

timer_mgr:once(4000, function()
    local ok, code, res = router_mgr:call_mongo_hash(1, "mongo_find", "default", "test_mongo_1", {}, {_id = 0})
    log_debug("db find ok:%s, code: %s, res = %s", ok, code, res)
end)

return RouterTest
