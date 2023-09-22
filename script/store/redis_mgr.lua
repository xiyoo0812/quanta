--redis_mgr.lua
local log_err       = logger.err
local log_debug     = logger.debug
local tpack         = table.pack
local tunpack       = table.unpack

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

function RedisMgr:execute(db_id, cmd, ...)
    local redisdb = self:get_db(db_id)
    if redisdb then
        local res = tpack(redisdb:execute(cmd, ...))
        if not res[1] then
            log_err("[RedisMgr][execute] execute {} ({}) failed, because: {}", cmd, {...}, res[2])
            return res[1] and SUCCESS or REDIS_FAILED, res[2]
        end
        log_debug("[RedisMgr][execute]: cmd {}, args: {}", cmd, {...})
        return SUCCESS, tunpack(res, 2)
    end
    return REDIS_FAILED, "redis db not exist"
end

function RedisMgr:available(db_id)
    local redisdb = self:get_db(db_id)
    if not redisdb then
        return false
    end
    return redisdb:available()
end

quanta.redis_mgr = RedisMgr()

return RedisMgr
