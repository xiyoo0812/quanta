--dbsvr.lua
import("kernel.lua")

local env_get       = environ.get

quanta.startup(function()
    --初始化dbsvr
    local service = env_get("QUANTA_SERVICE")
    if service == "mongo" then
        import("db/mongo_mgr.lua")
    elseif service == "mysql" then
        import("db/mysql_mgr.lua")
    elseif service == "redis" then
        import("db/redis_mgr.lua")
    end
end)
