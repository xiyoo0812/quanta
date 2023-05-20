--redis_mgr.lua
local tpack         = table.pack
local log_err       = logger.err

local event_mgr     = quanta.get("event_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local REDIS_FAILED  = quanta.enum("KernCode", "REDIS_FAILED")

local MAIN_DBID     = environ.number("QUANTA_DB_MAIN_ID")

local RedisMgr = singleton()
local prop = property(RedisMgr)
prop:reader("redis_dbs", {})    -- redis_dbs

function RedisMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_redis_execute", "execute")
end

--初始化
function RedisMgr:setup()
    local RedisDB = import("driver/redis.lua")
    local drivers = environ.driver("QUANTA_REDIS_URLS")
    for i, conf in ipairs(drivers) do
        local redis_db = RedisDB(conf, i)
        self.redis_dbs[i] = redis_db
    end
end

--查找redis db
function RedisMgr:get_db(db_id)
    return self.redis_dbs[db_id or MAIN_DBID]
end

function RedisMgr:execute(db_id, primary_id, cmd, ...)
    local redisdb = self:get_db(db_id)
    if redisdb then
        redisdb:set_executer(primary_id)
        local ok, res_oe = redisdb:execute(cmd, ...)
        if not ok then
            log_err("[RedisMgr][execute] execute %s (%s) failed, because: %s", cmd, tpack(...), res_oe)
        end
        return ok and SUCCESS or REDIS_FAILED, res_oe
    end
    return REDIS_FAILED, "redis db not exist"
end

quanta.redis_mgr = RedisMgr()

return RedisMgr
