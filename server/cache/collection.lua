-- collection.lua
local log_err       = logger.err
local qsuccess      = quanta.success
local qfailed       = quanta.failed

local Document      = import("cache/document.lua")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local KEY_NOT_EXIST = quanta.enum("CacheCode", "CACHE_KEY_IS_NOT_EXIST")

local Collection = class()
local prop = property(Collection)
prop:reader("flush", false)         -- flush status
prop:reader("lock_node_id", 0)      -- lock node id
prop:reader("expire_time", 600)     -- expire time
prop:reader("store_time", 300)      -- store time

prop:reader("primary_key", "")      -- primary key
prop:reader("coll_name", "")        -- coll name
prop:reader("group", "")            -- group

prop:reader("db_id", "")            -- db id
prop:reader("documents", {})        -- documents
prop:reader("dirty_documents", {})  -- dirty documents

function Collection:__init(conf)
    self.db_id = conf.id
    self.coll_name = conf.coll_name
    self.store_time = conf.store_time
    self.flush_time = conf.flush_time
    self.expire_time = conf.expire_time
    self.primary_key = conf.primary_key
end

function Collection:load(primary_value)
    local doc = self.documents[primary_value]
    if not doc then
        doc = Document(self.coll_name, self.primary_key, primary_value)
        local code = doc:load(self.db_id)
        if qfailed(code) then
            log_err("[Collection][load] load row failed: tab_name=%s", self.coll_name)
            return code
        end
        self.documents[primary_value] = doc
    end
    return SUCCESS, doc
end

function Collection:on_second(tick)
    if next(self.dirty_records) then
        return false
    end
    local escape_time = tick - self.active_tick
    if self.flush_time > 0 then
        return escape_time > self.flush_time
    end
    if not self.flush then
        return false
    end
    return escape_time > self.expire_time
end

function Collection:check_store(now)
    if self.store_count <= self.update_count or self.update_time + self.store_time < now then
        return self:save()
    end
    return false
end

function Collection:save(primary_key)
    self.active_tick = quanta.now
    if next(self.dirty_records) then
        self.update_count = 0
        self.update_time = quanta.now
        for record in pairs(self.dirty_records) do
            if qsuccess(record:save()) then
                self.dirty_records[record] = nil
            end
        end
        if next(self.dirty_records) then
            return false
        end
    end
    return true
end

function Collection:update(primary_value, coll_data, flush)
    local doc = self.documents[primary_value]
    if not doc then
        log_err("[Collection][update] cannot find record!, table:%s", self.coll_name)
        return KEY_NOT_EXIST
    end
    self.flush = false
    local code = doc:update(coll_data, flush)
    if doc:is_dirty() then
        self.dirty_records[doc] = true
    end
    return code
end

function Collection:update_fields(primary_value, fields, flush)
    local doc = self.documents[primary_value]
    if not doc then
        log_err("[Collection][update_fields] cannot find record!, table:%s", self.coll_name)
        return KEY_NOT_EXIST
    end
    self.flush = false
    local code = doc:update_fields(fields, flush)
    if doc:is_dirty() then
        self.dirty_records[doc] = true
    end
    return code
end

function Collection:remove_fields(primary_value, fields, flush)
    local doc = self.documents[primary_value]
    if not doc then
        log_err("[Collection][remove_fields] cannot find record!, table:%s", self.coll_name)
        return KEY_NOT_EXIST
    end
    self.flush = false
    local code = doc:remove_fields(fields, flush)
    if doc:is_dirty() then
        self.dirty_records[doc] = true
    end
    return code
end

return Collection
