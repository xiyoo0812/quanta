--redis_mq.lua
import("agent/redis_agent.lua")

local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local sformat       = string.format
local qsuccess      = quanta.success

local redis_agent   = quanta.get("redis_agent")

local CLUSTER       = environ.get("QUANTA_CLUSTER")

local RedisMQ = class()
local prop = property(RedisMQ)
prop:reader("expire_keys", {})  -- expire_keys
prop:reader("coll_name", "")    -- coll_name
prop:reader("prefix", nil)      -- prefix

function RedisMQ:__init()
end

function RedisMQ:setup(coll_name)
    self.coll_name = coll_name
    self.prefix = sformat("QUANTA:%s:RELIABLE:%s", CLUSTER, coll_name)
    log_info("[RedisMQ][setup] init rmsg coll: {}", coll_name)
end

-- 获取消息长度
function RedisMQ:len_message(target_id)
    local list_name = sformat("%s:%s", self.prefix, target_id)
    local ok, code, result = redis_agent:execute({ "LLEN", list_name})
    if qsuccess(code, ok) then
        return result
    end
    return 0
end

-- 查询未处理消息列表
function RedisMQ:list_message(target_id)
    local list_name = sformat("%s:%s", self.prefix, target_id)
    local ok, code, result = redis_agent:execute({ "LRANGE", list_name, 0, -1 }, target_id)
    if qsuccess(code, ok) then
        return result
    end
    return {}
end

-- 删除消息
function RedisMQ:delete_message(target_id, events)
    for _, event in ipairs(events) do
        log_debug("[RedisMQ][delete_message] delete message: {}-{}", target_id, event)
    end
    local list_name = sformat("%s:%s", self.prefix, target_id)
    return redis_agent:execute({ "LTRIM", list_name, #events, -1 }, target_id)
end

-- 发送消息
function RedisMQ:send_message(target_id, event, args, ttl)
    local timestamp = quanta.now_ms
    local doc = { args = args, event = event, time = timestamp }
    local list_name = sformat("%s:%s", self.prefix, target_id)
    local ok, code = redis_agent:execute({ "RPUSH", list_name, doc }, target_id)
    if qsuccess(code, ok) then
        if ttl then
            redis_agent:execute( { "EXPIRE", list_name, ttl }, target_id)
        end
        log_debug("[RedisMQ][send_message] send message succeed: {}, {}", target_id, doc)
        return true
    end
    log_err("[RedisMQ][send_message] send message failed: {}, {}", target_id, doc)
    return false
end

return RedisMQ
