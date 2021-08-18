-- redis_test.lua
local log_info  = logger.info
local serialize = logger.serialize

local DBGroup   = enum("DBGroup")

local timer_mgr = quanta.get("timer_mgr")

local RedisMgr = import("kernel/store/redis_mgr.lua")
local redis_mgr = RedisMgr(DBGroup.AREA)

timer_mgr:once(3000, function()    
    local code, res = redis_mgr:execute(3, "get", "aaa")
    log_info("db get code: %s, res = %s", code, serialize(res))
    code, res = redis_mgr:execute(3, "set", "aaa", 123)
    log_info("db set code: %s, res = %s", code, serialize(res))
    code, res = redis_mgr:execute(3, "get", "aaa")
    log_info("db get code: %s, res = %s", code, serialize(res))
    code, res = redis_mgr:execute(3, "del", "aaa")
    log_info("db del code: %s, res = %s", code, serialize(res))
    code, res = redis_mgr:execute(3, "get", "aaa")
    log_info("db get code: %s, res = %s", code, serialize(res))
    code, res = redis_mgr:execute(3, "hget", "bb", "k1")
    log_info("db hget code: %s, res = %s", code, serialize(res))
    code, res = redis_mgr:execute(3, "hset", "bb", "k1", 2)
    log_info("db hset code: %s, res = %s", code, serialize(res))
    code, res = redis_mgr:execute(3, "hget", "bb", "k1")
    log_info("db hget code: %s, res = %s", code, serialize(res))
    code, res = redis_mgr:execute(3, "hdel", "bb", "k1")
    log_info("db hdel code: %s, res = %s", code, serialize(res))
    code, res = redis_mgr:execute(3, "hget", "bb", "k1")
    log_info("db hget code: %s, res = %s", code, serialize(res))
    local code, res = redis_mgr:execute(3, "subscribe", "test")
    log_info("db subscribe code: %s, res = %s", code, serialize(res))
    code, res = redis_mgr:execute(3, "publish", "test", 123)
    log_info("db publish code: %s, res = %s", code, serialize(res))
end)