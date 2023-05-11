-- document.lua
local log_err       = logger.err
local qfailed       = quanta.failed
local ssplit        = qstring.split
local convint       = qmath.conv_integer

local mongo_mgr     = quanta.get("mongo_mgr")
local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local MAIN_DBID     = environ.number("QUANTA_DB_MAIN_ID")
local CACHE_EXPIRE  = environ.number("QUANTA_DB_CACHE_EXPIRE")

local Document = class()
local prop = property(Document)
prop:reader("coll_name", nil)       -- table name
prop:reader("primary_key", nil)     -- primary key
prop:reader("primary_id", nil)      -- primary id
prop:reader("update_time", 0)       -- update_time
prop:reader("datas", {})            -- datas
prop:accessor("lock_node_id", 0)    -- lock_node_id

--构造函数
function Document:__init(coll_name, primary_key, primary_id)
    self.coll_name = coll_name
    self.primary_id  = primary_id
    self.primary_key = primary_key
end

--从数据库加载
function Document:load()
    local query = { [self.primary_key] = self.primary_id }
    local code, res = mongo_mgr:find_one(MAIN_DBID, self.coll_name, query, { _id = 0 })
    if qfailed(code) then
        log_err("[Document][load] failed: %s=> table: %s", res, self.coll_name)
        return code
    end
    self.update_time = quanta.now
    self.datas = res or {}
    return code
end

--保存数据库
function Document:flush()
    self.update_time = quanta.now
    self.lock_node_id = 0
end

--保存数据库
function Document:update(udata)
    local updata = udata or { ["$set"] = self.datas }
    local selector = { [self.primary_key] = self.primary_id }
    local code, res = mongo_mgr:update(MAIN_DBID, self.coll_name, updata, selector, true)
    if qfailed(code) then
        log_err("[Document][update] failed: %s=> table: %s", res, self.coll_name)
        return false, code
    end
    return true, SUCCESS
end

--更新数据
function Document:update_field(field, field_data, flush)
    self:set_field(field, field_data)
    self.update_time = quanta.now
    if flush then
        if #field == 0 then
            return self:update()
        end
        return self:update({ ["$set"] = { [field] = field_data } })
    end
    return false
end

--删除子数据
function Document:remove_field(field, flush)
    self:unset_field(field)
    self.update_time = quanta.now
    if flush then
        return self:update({ ["$unset"] = { [field] = 1 } })
    end
    return false
end

--是否过期
function Document:is_expire(now)
    if self.lock_node_id > 0 then
        return false
    end
    return (self.update_time + CACHE_EXPIRE) < now
end

--内部接口
-------------------------------------------------------
--更新子数据
function Document:set_field(field, value)
    if #field == 0 then
        value[self.primary_key] = self.primary_id
        self.datas = value
        return
    end
    local cursor = self.datas
    local fields = ssplit(field, ".")
    local depth = #fields
    for i = 1, depth -1 do
        local cur_field = convint(fields[i])
        if not cursor[cur_field] then
            cursor[cur_field] = {}
        end
        cursor = cursor[cur_field]
    end
    local fine_field = convint(fields[depth])
    cursor[fine_field] = value
end

--更新子数据
function Document:unset_field(field)
    local cursor = self.datas
    local fields = ssplit(field, ".")
    local depth = #fields
    for i = 1, depth -1 do
        local cur_field = convint(fields[i])
        if not cursor[cur_field] then
            return
        end
        cursor = cursor[cur_field]
    end
    local fine_field = convint(fields[depth])
    cursor[fine_field] = nil
end

--序列化
function Document:serialize()
    local data = {
      coll_name = self.coll_name,
      primary_key = self.primary_key,
      primary_id = self.primary_id,
      datas = self.datas
    }
    return data
end

return Document
