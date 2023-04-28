--mongo_mq.lua
import("agent/mongo_agent.lua")
local lmongo        = require("lmongo")

local mdate         = lmongo.date
local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local qsuccess      = quanta.success

local mongo_agent   = quanta.get("mongo_agent")

local MongoMQ = class()
local prop = property(MongoMQ)
prop:reader("coll_name", "")    -- coll_name
prop:reader("ttl", nil)         -- ttl

function MongoMQ:__init()
end

function MongoMQ:setup(coll_name, ttl)
    self.coll_name = coll_name
    if ttl then
        self.ttl = ttl
        local query = { coll_name, { { key = { ttl = 1 }, expireAfterSeconds = 0, name = "ttl", unique = false } } }
        local ok, code = mongo_agent:create_indexes(query)
        if qsuccess(code, ok) then
            log_info("[MongoMQ][setup] rmsg table %s build due index success")
        end
    end
    log_info("[MongoMQ][setup] init rmsg coll: %s", coll_name)
end


-- 查询未处理消息列表
function MongoMQ:list_message(coll_name, target_id)
    local query = { coll_name, { target_id = target_id, deal_time = 0 }, nil, { time = 1 } }
    local ok, code, result = mongo_agent:find(query, target_id)
    if qsuccess(code, ok) then
        return result
    end
    return {}
end

-- 删除消息
function MongoMQ:delete_message(coll_name, target_id, timestamp)
    log_info("[MongoMQ][delete_message] delete message: %s", target_id)
    local selecter = { ["$and"] = { { target_id = target_id }, { time = {["$lte"] = timestamp } }}}
    return mongo_agent:delete({ coll_name, selecter }, target_id)
end

-- 发送消息
function MongoMQ:send_message(target_id, event, args)
    local doc = { args = args, event = event, target_id = target_id, time = quanta.now_ms }
    if self.ttl then
        --设置过期ttl字段
        doc.ttl = mdate(quanta.now + self.ttl)
    end
    local ok = mongo_agent:insert({ self.coll_name, doc }, target_id)
    if not ok then
        log_err("[MongoMQ][send_message] send message failed: %s, %s", target_id, args)
    end
    log_debug("[MongoMQ][send_message] send message succeed: %s, %s", target_id, args)
    return ok
end

return MongoMQ
