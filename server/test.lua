--testsvr.lua
import("kernel.lua")

local log_info      = logger.info
local qxpcall       = quanta.xpcall
local quanta_update = quanta.update

-- 初始化
if not quanta.init_flag then
    --初始化quanta

    qxpcall(quanta.init, "quanta.init error: %s")

    --[[
    import("case/oop_test.lua")
    import("case/http_test.lua")
    import("case/etcd_test.lua")
    import("case/json_test.lua")
    import("case/pack_test.lua")
    import("case/mongo_test.lua")
    import("case/protobuf_test.lua")
    ]]

    log_info("testsvr %d now startup!", quanta.id)
    quanta.init_flag = true  
    -- 设置启动标记
end

quanta.run = function()
    qxpcall(quanta_update, "quanta_update error: %s")
end

