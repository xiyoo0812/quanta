--quanta
import("kernel.lua")

quanta.startup(function()
    --初始化gm
    import("center/gm_cluster.lua")
    -- 协议过滤器
    import("center/center_gm.lua")
end)
