--qtest.lua
import("kernel.lua")

local log_info      = logger.info
local qxpcall       = quanta.xpcall
local quanta_update = quanta.update
local qxpcall_quit  = quanta.xpcall_quit

quanta.run = function()
    qxpcall(quanta_update, "quanta_update error: %s")
end

-- 初始化
if not quanta.init_flag then
    local function startup()
        --初始化quanta
        quanta.init()
        --初始化test
        --[[
        import("qtest/oop_test.lua")
        import("qtest/etcd_test.lua")
        import("qtest/json_test.lua")
        import("qtest/pack_test.lua")
        import("qtest/mongo_test.lua")
        import("qtest/router_test.lua")
        import("qtest/protobuf_test.lua")
        import("qtest/http_test.lua")
        import("qtest/rpc_test.lua")
        import("qtest/log_test.lua")
        ]]
        import("qtest/mongo_test.lua")
        log_info("qtest %d now startup!", quanta.id)
    end
    qxpcall_quit(startup, "quanta startup error: %s")
    quanta.init_flag = true
end
