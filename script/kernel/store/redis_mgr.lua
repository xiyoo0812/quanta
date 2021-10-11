--redis_mgr.lua
local hash_code     = utility.hash_code

local DBGroup       = enum("DBGroup")
local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local REDIS_FAILED  = KernCode.REDIS_FAILED

local config_mgr    = quanta.get("config_mgr")

local RedisMgr = class()
local prop = property(RedisMgr)
prop:accessor("hash_mode", false)   -- hash_mode
prop:accessor("redis_dbs", {})      -- redis_dbs

function RedisMgr:__init(group)
    self:setup(group)
    self.hash_mode = (group == DBGroup.HASH)
end

--初始化
function RedisMgr:setup(group)
    local RedisDB = import("driver/redis.lua")
    local database = config_mgr:get_table("database")
    for _, conf in database:iterator() do
        if group == conf.group and conf.driver == "redis" then
            self.redis_dbs[conf.index] = RedisDB(conf)
        end
    end
end

--查找redis db
function RedisMgr:get_db(index)
    if self.hash_mode then
        local hash_index = hash_code(index, #self.redis_dbs)
        return self.redis_dbs[hash_index]
    end
    return self.redis_dbs[index]
end

function RedisMgr:execute(index, cmd, ...)
    local redisdb = self:get_db(index)
    if redisdb then
        local ok, res_oe = redisdb:execute(cmd, ...)
        return ok and SUCCESS or REDIS_FAILED, res_oe
    end
    return REDIS_FAILED, "redis db not exist"
end

return RedisMgr
