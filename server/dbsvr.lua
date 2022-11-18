--dbsvr.lua
import("kernel.lua")

local env_get       = environ.get

quanta.startup(function()
    --初始化dbsvr
    local service = env_get("QUANTA_SERVICE")
    if service == "mongo" then
        import("store/mongo_mgr.lua")
    elseif service == "mysql" then
        import("store/mysql_mgr.lua")
    elseif service == "redis" then
        import("store/redis_mgr.lua")
    end
end)
