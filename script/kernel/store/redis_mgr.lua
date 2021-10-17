--redis_mgr.lua

local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local REDIS_FAILED  = KernCode.REDIS_FAILED

local event_mgr     = quanta.get("event_mgr")
local config_mgr    = quanta.get("config_mgr")

local RedisMgr = class()
local prop = property(RedisMgr)
prop:accessor("redis_dbs", {})      -- redis_dbs
prop:accessor("default_db", nil)    -- default_db

function RedisMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "redis_execute", "execute")
end

--初始化
function RedisMgr:setup()
    local RedisDB = import("driver/redis.lua")
    local database = config_mgr:init_table("database", "db")
    for _, conf in database:iterator() do
        if conf.driver == "redis" then
            local redis_db = RedisDB(conf)
            self.redis_dbs[conf.db] = redis_db
            if conf.default then
                self.default_db = redis_db
            end
        end
    end
end

--查找redis db
function RedisMgr:get_db(db_name)
    if db_name and db_name ~= "default" then
        return self.redis_dbs[db_name]
    end
    return self.default_db
end

function RedisMgr:execute(db_name, cmd, ...)
    local redisdb = self:get_db(db_name)
    if redisdb then
        local ok, res_oe = redisdb:execute(cmd, ...)
        return ok and SUCCESS or REDIS_FAILED, res_oe
    end
    return REDIS_FAILED, "redis db not exist"
end

return RedisMgr
