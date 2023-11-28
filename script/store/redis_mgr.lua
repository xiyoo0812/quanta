--redis_mgr.lua
local log_err       = logger.err
local log_debug     = logger.debug
local tpack         = table.pack
local tunpack       = table.unpack

local event_mgr     = quanta.get("event_mgr")

local BENCHMARK     = environ.number("QUANTA_DB_BENCHMARK")
local AUTOINCKEY    = environ.get("QUANTA_DB_AUTOINCKEY", "QUANTA:COUNTER:AUTOINC")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local REDIS_FAILED  = quanta.enum("KernCode", "REDIS_FAILED")

local RedisMgr = singleton()
local prop = property(RedisMgr)
prop:reader("redis_db", nil)    --redis_db

function RedisMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_redis_execute", "execute")
    event_mgr:add_listener(self, "rpc_redis_autoinc_id", "autoinc_id")
end

--初始化
function RedisMgr:setup()
    local RedisDB = import("driver/redis.lua")
    local driver = environ.driver("QUANTA_REDIS_URL")
    self.redis_db = RedisDB(driver)
end

function RedisMgr:execute(cmd, ...)
    if self.redis_db then
        log_debug("[RedisMgr][execute]: cmd {}, args: {}", cmd, {...})
        local res = tpack(self.redis_db:execute(cmd, ...))
        if not res[1] then
            log_err("[RedisMgr][execute] execute {} ({}) failed, because: {}", cmd, {...}, res[2])
            return res[1] and SUCCESS or REDIS_FAILED, res[2]
        end
        return SUCCESS, tunpack(res, 2)
    end
    return REDIS_FAILED, "redis db not exist"
end

function RedisMgr:autoinc_id()
    local aok, origin_id = self.redis_db:execute("INCR", AUTOINCKEY)
    if not aok then
        return REDIS_FAILED, origin_id
    end
    if BENCHMARK then
        return SUCCESS, BENCHMARK + origin_id
    end
    return SUCCESS, origin_id
end

function RedisMgr:available()
    if not self.redis_db then
        return false
    end
    return self.redis_db:available()
end

quanta.redis_mgr = RedisMgr()

return RedisMgr
