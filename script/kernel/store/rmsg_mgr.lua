--rmsg_mgr.lua
import("agent/mongo.lua")

local tsort     = table.sort
local errcode   = err.Code
local new_guid  = guid.new
local log_err   = logger.err
local log_info  = logger.info

local mongo_agent = quanta.mongo_agent

local RMsgMgr = class()

function RMsgMgr:__init(name)
    self.db_table_name = name
    log_info("[RMsgMgr][init] init rmsg table: %s", name)
end

-- 查询未处理消息列表
function RMsgMgr:list_message(to)
    local query = {self.db_table_name, {to = to, deal_time = 0}, {_id = 0}}
    local ok, code, result = mongo_agent:find(to, query)
    if ok and code == errcode.SUCCESS then
        tsort(result, function(a, b)
            return a.time < b.time
        end)
        return result
    end
end

-- 设置信息为已处理
function RMsgMgr:deal_message(to, uuid)
    log_info("[RMsgMgr][deal_message] deal message: %s", uuid)
    local query = {self.db_table_name, {["$set"] = {deal_time = quanta.now}}, {uuid = uuid}}
    mongo_agent:update(to, query)
end

-- 删除消息
function RMsgMgr:delete_message(to, uuid)
    log_info("[RMsgMgr][delete_message] delete message: %s", uuid)
    mongo_agent:delete(to, {self.db_table_name, {uuid = uuid}})
end

-- 发送消息
function RMsgMgr:send_message(from, to, typ, body, id)
    local uuid = id or new_guid()
    local doc = {
        uuid = uuid,
        from = from, to = to,
        type = typ, body = body,
        time = quanta.now,
        deal_time = 0,
    }
    local ok = mongo_agent:insert(to, {self.db_table_name, doc})
    if not ok then
        log_err("[RMsgMgr][send_message] send message failed: %s, %s, %s, %s", uuid, from, to, typ)
    else
        log_info("[RMsgMgr][send_message] send message succeed: %s, %s, %s, %s", uuid, from, to, typ)
    end
    return ok
end

return RMsgMgr
