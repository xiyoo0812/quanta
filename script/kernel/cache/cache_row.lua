-- cache_row.lua
-- cache单行
local log_err       = logger.err
local check_failed  = utility.check_failed

local KernCode      = enum("KernCode")
local CacheCode     = enum("CacheCode")
local SUCCESS       = KernCode.SUCCESS

local CacheRow = class()
local prop = property(CacheRow)
prop:accessor("cache_table", nil)       -- cache table
prop:accessor("cache_key", "")          -- cache key
prop:accessor("primary_value", nil)     -- primary value
prop:accessor("total_table", nil)       -- total table
prop:accessor("database_id", 0)         -- database id
prop:accessor("databese_mgr", nil)      -- databese mgr
prop:accessor("dirty", false)           -- dirty
prop:accessor("data", {})               -- data

--构造函数
function CacheRow:__init(databese_mgr, row_conf, primary_value, total_table, data)
    self.total_table    = total_table
    self.databese_mgr   = databese_mgr
    self.primary_value  = primary_value
    self.cache_table    = row_conf.cache_table
    self.cache_key      = row_conf.cache_key
    self.data = data or {}
end

--从数据库加载
function CacheRow:load(db_id)
    self.database_id = db_id
    local query = { [self.cache_key] = self.primary_value }
    local code, res = self.databese_mgr:find_one(db_id, self.cache_table, query, {_id = 0})
    if check_failed(code) then
        log_err("[CacheRow][load] failed: %s=> db: %s, table: %s", res, self.database_id, self.cache_table)
        return code
    end
    self.data = res
    return code
end

--保存数据库
function CacheRow:save()
    if self.dirty then
        local selector = { [self.cache_key] = self.primary_value }
        if self.total_table then
            local update_obj = {["$set"] = { [self.cache_table] = self.data }}
            local code, res = self.databese_mgr:update(self.database_id, self.total_table, update_obj, selector)
            if check_failed(code) then
                log_err("[CacheRow][save] failed: %s=> db: %s, table: %s", res, self.database_id, self.cache_table)
                return code
            end
            self.dirty = false
            return code
        else
            local code, res = self.databese_mgr:update(self.database_id, self.cache_table, self.data, selector, true)
            if check_failed(code) then
                log_err("[CacheRow][save] failed: %s=> db: %s, table: %s", res, self.database_id, self.cache_table)
                return code
            end
            self.dirty = false
            return code
        end
    end
    return SUCCESS
end

--更新数据
function CacheRow:update(data, flush)
    self.data = data
    self.dirty = true
    if flush then
        local code = self:save()
        if check_failed(code) then
            log_err("[CacheRow][update] flush failed: db: %s, table: %s", self.database_id, self.cache_table)
            return CacheCode.CACHE_FLUSH_FAILED
        end
    end
    return SUCCESS
end

--更新子数据
function CacheRow:update_key(key, value, flush)
    self.data[key] = value
    self.dirty = true
    if flush then
        local code = self:save()
        if check_failed(code) then
            log_err("[CacheRow][update_key] flush failed: db: %s, table: %s", self.database_id, self.cache_table)
            return CacheCode.CACHE_FLUSH_FAILED
        end
    end
    return SUCCESS
end

return CacheRow
