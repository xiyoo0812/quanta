-- redis_cluster.lua
local log_debug = logger.debug

local timer_mgr = quanta.get("timer_mgr")

local RedisMgr  = import("store/redis_mgr.lua")
local redis_mgr = RedisMgr()

local MAIN_DBID = environ.number("QUANTA_DB_MAIN_ID")

timer_mgr:once(2000, function()
    local code, res = redis_mgr:execute(MAIN_DBID, "cluster", "nodes")
    log_debug("db get code: {}, res({}) = {}", code, type(res), res)
    code, res = redis_mgr:execute(MAIN_DBID, "cluster", "slots")
    log_debug("db get code: {}, res({}) = {}", code, type(res), res)
    code, res = redis_mgr:execute(MAIN_DBID, "set", "aaa", {abc = 3, ddd = 4})
    log_debug("db set code: {}, res = {}", code, res)
    code, res = redis_mgr:execute(MAIN_DBID, "get", "aaa")
    log_debug("db get code: {}, res = {}", code, res)
    local code1, res1, res2 = redis_mgr:execute(MAIN_DBID, "scan", "0")
    log_debug("db scan code: {}, res = {}, res2={}", code1, res1, res2)
end)