-- document.lua
local log_err       = logger.err
local qfailed       = quanta.failed
local ssplit        = qstring.split

local mongo_mgr     = quanta.get("mongo_mgr")
local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local Document = class()
local prop = property(Document)
prop:reader("db_id", 1)             -- db id
prop:reader("coll_name", nil)       -- table name
prop:reader("primary_key", "")      -- primary key
prop:reader("primary_value", nil)   -- primary value
prop:reader("update_time", 0)       -- update time
prop:reader("dirty", false)         -- dirty
prop:reader("fields", {})           -- fields
prop:reader("data", {})             -- data

--构造函数
function Document:__init(coll_name, primary_key, primary_value)
    self.coll_name = coll_name
    self.primary_key = primary_key
    self.primary_value  = primary_value
end

--从数据库加载
function Document:load(db_id)
    self.db_id = db_id
    local query = { [self.primary_value] = self.primary_value }
    local code, res = mongo_mgr:find_one(self.db_id, self.coll_name, query, {_id = 0})
    if qfailed(code) then
        log_err("[Document][load] failed: %s=> db: %s, table: %s", res, self.db_id, self.coll_name)
        return code
    end
    self.update_time = quanta.now
    self.data = res
    return code
end

--保存数据库
function Document:save()
    if self.dirty then
        local selector = { [self.primary_value] = self.primary_value }
        local code, res = mongo_mgr:update(self.db_id, self.coll_name, self.data, selector, true)
        if qfailed(code) then
            log_err("[Document][save] failed: %s=> db: %s, table: %s", res, self.db_id, self.coll_name)
            return code
        end
        self.dirty = false
        return code
    end
    return SUCCESS
end

--更新数据
function Document:update(data, flush)
    self.data = data
    self.dirty = true
    self.update_time = quanta.now
    if flush then
        return self:save()
    end
    return SUCCESS
end

--更新子数据
function Document:update_fields(fields, flush)
    for field_key, value in pairs(fields) do
        self:update_field(field_key, value)
    end
    self.dirty = true
    self.update_time = quanta.now
    if flush then
        return self:save()
    end
    return SUCCESS
end

--删除子数据
function Document:remove_fields(fields, flush)
    for field_key in pairs(fields) do
        self:remove_field(field_key)
    end
    self.dirty = true
    self.update_time = quanta.now
    if flush then
        return self:save()
    end
    return SUCCESS
end

--内部接口
-------------------------------------------------------
--更新子数据
function Document:update_field(field_key, value)
    local node = self.data
    local fields = ssplit(field_key, ".")
    local depth = #fields
    for i = 1, depth -1 do
        node = node[fields[i]]
    end
    node[fields[depth]] = value
end

--更新子数据
function Document:remove_field(field_key)
    local node = self.data
    local fields = ssplit(field_key, ".")
    local depth = #fields
    for i = 1, depth -1 do
        node = node[fields[i]]
    end
    node[fields[depth]] = nil
end

return Document
