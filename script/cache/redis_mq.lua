--redis_mq.lua
import("agent/redis_agent.lua")
local ljson         = require("lcjson")

local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local json_encode   = ljson.encode
local json_decode   = ljson.decode
local sformat       = string.format
local qsuccess      = quanta.success

local redis_agent   = quanta.get("redis_agent")
local NAMESPACE     = environ.get("QUANTA_NAMESPACE")

local RedisMQ = class()
local prop = property(RedisMQ)
prop:reader("expire_keys", {})  -- expire_keys
prop:reader("coll_name", "")    -- coll_name
prop:reader("prefix", nil)      -- prefix
prop:reader("ttl", nil)         -- ttl

function RedisMQ:__init()
end

function RedisMQ:setup(coll_name, ttl)
    self.ttl = ttl
    self.coll_name = coll_name
    self.prefix = sformat("RELIABLE:%s:%s", NAMESPACE, coll_name)
    log_info("[RedisMQ][setup] init rmsg coll: %s", coll_name)
end

-- 查询未处理消息列表
function RedisMQ:list_message(target_id)
    local zset_name = sformat("%s:%s", self.prefix, target_id)
    local ok, code, result = redis_agent:execute({ "ZRANGE", zset_name, 0, -1 }, target_id)
    if qsuccess(code, ok) then
        for i, msg in ipairs(result) do
            result[i] = json_decode(msg)
        end
        return result
    end
    return {}
end

-- 删除消息
function RedisMQ:delete_message(target_id, timestamp)
    log_info("[RedisMQ][delete_message] delete message: %s-%s", target_id, timestamp)
    local zset_name = sformat("%s:%s", self.prefix, target_id)
    return redis_agent:execute({ "ZREMRANGEBYSCORE", zset_name, 0, timestamp }, target_id)
end

-- 发送消息
function RedisMQ:send_message(target_id, event, args)
    local timestamp = quanta.now_ms
    local doc = { args = args, event = event, time = timestamp }
    local zset_name = sformat("%s:%s", self.prefix, target_id)
    local ok, code = redis_agent:execute({ "ZADD", zset_name, timestamp, json_encode(doc) }, target_id)
    if qsuccess(code, ok) then
        if self.ttl then
            redis_agent:execute( { "EXPIRE", zset_name, self.ttl }, target_id)
        end
        log_debug("[RedisMQ][send_message] send message succeed: %s, %s", target_id, doc)
    end
    log_err("[RedisMQ][send_message] send message failed: %s, %s", target_id, doc)
    return ok
end

return RedisMQ
