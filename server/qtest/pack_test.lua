-- pack_test.lua
local tinsert       = table.insert
local tconcat       = table.concat
local log_info      = logger.info
local sname2sid     = service.name2sid

local router_mgr    = quanta.router_mgr

local PackTest = singleton()
function PackTest:__init()
    local service_id = sname2sid("logsvr")
    router_mgr:watch_server_register(self, service_id)
end

function PackTest:on_server_register(quanta_id)
    local service_id = sname2sid("logsvr")
    local router = router_mgr:random_router(service_id)
    if router then
        local strs, args = {}, {}
        for i = 1, 1000 do
            tinsert(strs, "arg2....................")
        end
        local ss = tconcat(strs)
        for i= 1, 100000 do
            tinsert(args, ss)
        end
        local _, send_len = router.socket.call_target(quanta_id, "test_log", 0, "arg_1", args, "arg_3")
        log_info("[PackTest][on_server_register] send size : %s", send_len)
    end
end

-- export
quanta.pack_test = PackTest()

return PackTest