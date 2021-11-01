--dbsvr.lua
import("kernel.lua")

local env_get       = environ.get

quanta.startup(function()
    --初始化dbsvr
    local db_driver = env_get("QUANTA_DB_DRIVER")
    if db_driver == "mongo" then
        import("kernel/store/mongo_mgr.lua")
    elseif db_driver == "mysql" then
        import("kernel/store/mysql_mgr.lua")
    elseif db_driver == "redis" then
        import("kernel/store/redis_mgr.lua")
    end
end)
