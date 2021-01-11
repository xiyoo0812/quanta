--rmsg_mgr.lua
import("kernel/store/db_agent.lua")

local tsort         = table.sort
local new_guid      = guid.new
local log_err       = logger.err
local log_info      = logger.info

local db_agent      = quanta.db_agent
local check_success = utility.check_success

local DBGroup       = enum("DBGroup")
local DBGROUP_HASH  = DBGroup.HASH

local RmsgMgr = class()

function RmsgMgr:__init(name)
    self.db_table_name = name
    log_info("[RmsgMgr][init] init rmsg table: %s", name)
end

-- 查询未处理消息列表
function RmsgMgr:list_message(to)
    local query = {self.db_table_name, {to = to, deal_time = 0}, {_id = 0}}
    local ok, code, result = db_agent:find(to, query, DBGROUP_HASH, to)
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
    return db_agent:update(to, query, DBGROUP_HASH, to)
end

-- 删除消息
function RmsgMgr:delete_message(to, uuid)
    log_info("[RmsgMgr][delete_message] delete message: %s", uuid)
    return db_agent:delete(to, {self.db_table_name, {uuid = uuid}}, DBGROUP_HASH, to)
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
    local ok = db_agent:insert(to, {self.db_table_name, doc}, DBGROUP_HASH, to)
    if not ok then
        log_err("[RmsgMgr][send_message] send message failed: %s, %s, %s, %s", uuid, from, to, typ)
    else
        log_info("[RmsgMgr][send_message] send message succeed: %s, %s, %s, %s", uuid, from, to, typ)
    end
    return ok
end

return RmsgMgr
