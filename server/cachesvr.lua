--quanta
import("kernel.lua")

quanta.startup(function()
    --初始化cachesvr
    import("cache/cache_mgr.lua")
    import("cache/cache_gm.lua")
end)
