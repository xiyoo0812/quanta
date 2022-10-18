--reliable_msg.lua
import("agent/mongo_agent.lua")
local lmongo        = require("lmongo")

local mdate         = lmongo.date
local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local qsuccess      = quanta.success

local mongo_agent   = quanta.get("mongo_agent")

local MSG_DBID      = environ.number("QUANTA_MONGO_MSG_ID")

local ReliabledMsg = class()
local prop = property(ReliabledMsg)
prop:reader("coll_name", "")    -- coll_name
prop:reader("ttl", nil)         -- ttl

function ReliabledMsg:__init()
end

function ReliabledMsg:setup(coll_name, ttl)
    self.coll_name = coll_name
    if ttl then
        self.ttl = ttl
        local query = { coll_name, { { key = { ttl = 1 }, expireAfterSeconds = 0, name = "ttl", unique = false } } }
        local ok, code = mongo_agent:create_indexes(query, nil, MSG_DBID)
        if ok and qsuccess(code) then
            log_info("[ReliabledMsg][setup] rmsg table %s build due index success")
        end
    end
    log_info("[ReliabledMsg][setup] init rmsg coll: %s", coll_name)
end


-- 查询未处理消息列表
function ReliabledMsg:list_message(coll_name, target_id)
    local query = { coll_name, { target_id = target_id, deal_time = 0 }, nil, { time = 1 } }
    local ok, code, result = mongo_agent:find(query, target_id, MSG_DBID)
    if ok and qsuccess(code) then
        return result
    end
end

-- 设置信息为已处理
function ReliabledMsg:deal_message(coll_name, target_id, timestamp)
    log_info("[ReliabledMsg][deal_message] deal message: %s", target_id)
    local selecter = { ["$and"] = { { target_id = target_id }, { time = { ["$lt"] = timestamp } }}}
    local query = { coll_name, {["$set"] = { deal_time = "$$CLUSTER_TIME" }}, selecter }
    return mongo_agent:update(query, target_id, MSG_DBID)
end

-- 删除消息
function ReliabledMsg:delete_message(coll_name, target_id, timestamp)
    log_info("[ReliabledMsg][delete_message] delete message: %s", target_id)
    local selecter = { ["$and"] = { { target_id = target_id }, { time = {["$lt"] = timestamp } }}}
    return mongo_agent:delete({ coll_name, selecter }, target_id, MSG_DBID)
end

-- 发送消息
function ReliabledMsg:send_message(target_id, event, args)
    local doc = { args = args, deal_time = 0, event = event, target_id = target_id, time = "$$CLUSTER_TIME" }
    if self.ttl then
        --设置过期ttl字段
        doc.ttl = mdate(quanta.now + self.ttl)
    end
    doc.source = quanta.service_name
    local ok = mongo_agent:insert({ self.coll_name, doc }, target_id, MSG_DBID)
    if not ok then
        log_err("[ReliabledMsg][send_message] send message failed: %s, %s", target_id, args)
    end
    log_debug("[ReliabledMsg][send_message] send message succeed: %s, %s", target_id, args)
    return ok
end

return ReliabledMsg
