#!./quanta
import("kernel.lua")

quanta.startup(function()
    --初始化online
    import("kernel/online/online_mgr.lua")
end)