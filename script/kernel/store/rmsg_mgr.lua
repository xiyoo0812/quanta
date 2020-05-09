--rmsg_mgr.lua
import("kernel/store/mongo_proxy.lua")

local tsort     = table.sort
local new_guid  = guid.new
local log_err   = logger.err
local log_info  = logger.info

local mongo_proxy   = quanta.mongo_proxy
local check_success = utility.check_success

local RmsgMgr = class()

function RmsgMgr:__init(name)
    self.db_table_name = name
    log_info("[RmsgMgr][init] init rmsg table: %s", name)
end

-- 查询未处理消息列表
function RmsgMgr:list_message(to)
    local query = {self.db_table_name, {to = to, deal_time = 0}, {_id = 0}}
    local ok, code, result = mongo_proxy:find(to, query, 2)
    if ok and check_success(code) then
        tsort(result, function(a, b)
            return a.time < b.time
        end)
        return result
    end
end

-- 设置信息为已处理
function RmsgMgr:deal_message(to, uuid)
    log_info("[RmsgMgr][deal_message] deal message: %s", uuid)
    local query = {self.db_table_name, {["$set"] = {deal_time = quanta.now}}, {uuid = uuid}}
    mongo_proxy:update(to, query, 2)
end

-- 删除消息
function RmsgMgr:delete_message(to, uuid)
    log_info("[RmsgMgr][delete_message] delete message: %s", uuid)
    mongo_proxy:delete(to, {self.db_table_name, {uuid = uuid}}, 2)
end

-- 发送消息
function RmsgMgr:send_message(from, to, typ, body, id)
    local uuid = id or new_guid()
    local doc = {
        uuid = uuid,
        from = from, to = to,
        type = typ, body = body,
        time = quanta.now,
        deal_time = 0,
    }
    local ok = mongo_proxy:insert(to, {self.db_table_name, doc}, 2)
    if not ok then
        log_err("[RmsgMgr][send_message] send message failed: %s, %s, %s, %s", uuid, from, to, typ)
    else
        log_info("[RmsgMgr][send_message] send message succeed: %s, %s, %s, %s", uuid, from, to, typ)
    end
    return ok
end

return RmsgMgr
