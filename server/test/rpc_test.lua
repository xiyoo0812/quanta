-- mongo_test.lua
local log_debug     = logger.debug

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local router_mgr    = quanta.get("router_mgr")

local RpcTest = singleton()

function RpcTest:__init()
    self:setup()
end

function RpcTest:setup()
    event_mgr:add_listener(self, "on_echo")

    thread_mgr:fork(function()
        local data = {}
        for l = 1, 61 do
            for m = 1, 1024 do
                table.insert(data, 1*m)
            end
        end
        thread_mgr:sleep(3000)
        for n = 1, 200 do
            local ok, rn, rdata = router_mgr:call_target(quanta.id, "on_echo", n, data)
            if ok then
                log_debug("%s res: %s", rn, #rdata)
            else
                log_debug("%s err: %s", n, rn)
            end
        end
    end)
end

function RpcTest:on_echo(n, data)
    log_debug("%s req: %s", n, #data)
    return n, data
end

-- export
quanta.rpc_test = RpcTest()

return RpcTest

