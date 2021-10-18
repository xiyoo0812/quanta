--dbsvr.lua
import("kernel.lua")

local log_info      = logger.info
local env_get       = environ.get
local qxpcall_quit  = quanta.xpcall_quit

if not quanta.init_flag then
    local function startup()
        --初始化quanta
        quanta.init()
        --初始化dbsvr
        local db_driver = env_get("QUANTA_DB_DRIVER")
        if db_driver == "mongo" then
            local MongoMgr = import("kernel/store/mongo_mgr.lua")
            quanta.mongo_mgr = MongoMgr()
            log_info("mongo svr %d now startup!", quanta.id)
        elseif db_driver == "mysql" then
            local MysqlMgr = import("kernel/store/mysql_mgr.lua")
            quanta.mysql_mgr = MysqlMgr()
            log_info("mysql svr %d now startup!", quanta.id)
        elseif db_driver == "redis" then
            local RedisMgr = import("kernel/store/redis_mgr.lua")
            quanta.redis_mgr = RedisMgr()
            log_info("redis svr %d now startup!", quanta.id)
        end
    end
    qxpcall_quit(startup, "quanta startup error: %s")
    quanta.init_flag = true
end
