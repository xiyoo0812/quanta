--testsvr.lua
import("quanta.lua")

local log_info      = logger.info
local hxpcall       = quanta.xpcall
local quanta_update = quanta.update

-- 初始化
if not quanta.init_flag then
    local opts =
    {
        index   = 1,                --instance index
        log     = "test",           --log file: router
    }

    --初始化quanta
    quanta.init("testsvr", opts)

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
    quanta.init_flag = true  -- 设置启动标记
end

quanta.run = function()
    hxpcall(quanta_update, "quanta_update error: %s")
end
