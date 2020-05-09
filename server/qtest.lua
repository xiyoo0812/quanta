--qtest.lua
import("kernel.lua")

local log_info      = logger.info
local qxpcall       = quanta.xpcall
local quanta_update = quanta.update

-- 初始化
if not quanta.init_flag then
    local function startup()
        --初始化quanta
        quanta.init()
        --初始化test
        --[[
        import("qtest/oop_test.lua")
        import("qtest/http_test.lua")
        import("qtest/etcd_test.lua")
        import("qtest/json_test.lua")
        import("qtest/pack_test.lua")
        import("qtest/mongo_test.lua")
        import("qtest/router_test.lua")
        import("qtest/protobuf_test.lua")
        ]]
        log_info("qtest %d now startup!", quanta.id)
    end
    qxpcall(startup, "quanta startup error: %s")
    quanta.init_flag = true
end

quanta.run = function()
    qxpcall(quanta_update, "quanta_update error: %s")
end

