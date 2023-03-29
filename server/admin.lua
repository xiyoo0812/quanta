#!./quanta
import("kernel.lua")

quanta.startup(function()
    --初始化admin
    import("admin/admin_mgr.lua")
    -- 协议过滤器
    import("admin/admin_gm.lua")
end)
