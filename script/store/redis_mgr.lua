--redis_mgr.lua
local tpack         = table.pack
local log_err       = logger.err

local event_mgr     = quanta.get("event_mgr")
local config_mgr    = quanta.get("config_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local REDIS_FAILED  = quanta.enum("KernCode", "REDIS_FAILED")

local RedisMgr = singleton()
local prop = property(RedisMgr)
prop:reader("redis_dbs", {})    -- redis_dbs
prop:reader("default_db", nil)  -- default_db
prop:reader("default_id", nil)  -- default_id

function RedisMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_redis_execute", "execute")
end

--初始化
function RedisMgr:setup()
    local RedisDB = import("driver/redis.lua")
    local database = config_mgr:init_table("database", "db", "driver")
    for _, conf in database:iterator() do
        if conf.driver == "redis" then
            local redis_db = RedisDB(conf)
            self.redis_dbs[conf.id] = redis_db
            if conf.default then
                self.default_id = conf.id
                self.default_db = redis_db
            end
        end
    end
    config_mgr:close_table("database")
end

--查找redis db
function RedisMgr:get_db(db_id)
    if not db_id or db_id == self.default_id then
        return self.default_db
    end
    return self.redis_dbs[db_id]
end

function RedisMgr:execute(db_id, cmd, ...)
    local redisdb = self:get_db(db_id)
    if redisdb then
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
