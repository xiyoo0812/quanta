--mongo_mq.lua
import("agent/mongo_agent.lua")

local bdate         = bson.date
local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local qsuccess      = quanta.success
local new_guid      = codec.guid_new

local mongo_agent   = quanta.get("mongo_agent")

local MongoMQ = class()
local prop = property(MongoMQ)
prop:reader("coll_name", "")    -- coll_name

function MongoMQ:__init()
end

function MongoMQ:setup(coll_name)
    self.coll_name = coll_name
    local query = { coll_name, { { key = { ttl = 1 }, expireAfterSeconds = 0, name = "ttl", unique = false } } }
    local ok, code = mongo_agent:create_indexes(query)
    if qsuccess(code, ok) then
        log_info("[MongoMQ][setup] rmsg table {} build due index success")
    end
    log_info("[MongoMQ][setup] init rmsg coll: {}", coll_name)
end

-- 获取消息长度
function MongoMQ:len_message(target_id)
    local query = { self.coll_name, { target_id = target_id }}
    local ok, code, result = mongo_agent:count(query, target_id)
    if qsuccess(code, ok) then
        return result
    end
    return 0
end


-- 查询未处理消息列表
function MongoMQ:list_message(target_id)
    local query = { self.coll_name, { target_id = target_id }, nil, { time = 1 } }
    local ok, code, result = mongo_agent:find(query, target_id)
    if qsuccess(code, ok) then
        return result
    end
end

-- 删除消息
function MongoMQ:delete_message(target_id, events)
    for _, event in ipairs(events) do
        log_debug("[RedisMQ][delete_message] delete message: {}-{}", target_id, event)
        mongo_agent:delete({ self.coll_name, { uuid = event.uuid } }, target_id)
    end
end

-- 发送消息
function MongoMQ:send_message(target_id, event, args, ttl)
    local doc = { args = args, event = event, target_id = target_id, time = quanta.now_ms, uuid = new_guid() }
    if ttl then
        --设置过期ttl字段
        doc.ttl = bdate(quanta.now + ttl)
    end
    local ok = mongo_agent:insert({ self.coll_name, doc }, target_id)
    if not ok then
        log_err("[MongoMQ][send_message] send message failed: {}, {}", target_id, args)
        return ok
    end
    log_debug("[MongoMQ][send_message] send message succeed: {}, {}", target_id, args)
    return ok
end

return MongoMQ
