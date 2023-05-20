-- collection.lua
local log_err       = logger.err
local log_info      = logger.info
local qfailed       = quanta.failed

local Document      = import("cache/document.lua")
local QueueLRU      = import("container/queue_lru.lua")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local CACHE_MAX     = environ.number("QUANTA_DB_CACHE_MAX")
local CACHE_TIME    = environ.number("QUANTA_DB_CACHE_TIME")
local CACHE_COUNT   = environ.number("QUANTA_DB_CACHE_COUNT")

local Collection = class()
local prop = property(Collection)
prop:reader("update_count", 0)      -- update count
prop:reader("update_time", 0)       -- update time

prop:reader("group", nil)           -- group
prop:reader("coll_name", nil)       -- coll name
prop:reader("primary_key", nil)     -- primary key
prop:reader("documents", nil)       -- documents
prop:reader("dirty_documents", {})  -- dirty documents

function Collection:__init(coll_name, primary_key, group)
    self.documents = QueueLRU(CACHE_MAX)
    self.update_time = quanta.now
    self.primary_key = primary_key
    self.coll_name = coll_name
    self.group = group
end

function Collection:load(primary_id)
    local doc = self.documents:get(primary_id)
    if not doc then
        doc = Document(self.coll_name, self.primary_key, primary_id)
        local code = doc:load()
        if qfailed(code) then
            log_err("[Collection][load] load row failed: tab_name=%s", self.coll_name)
            return code
        end
        self.documents:set(primary_id, doc)
        log_info("[Collection][load] collection %s now has %s documents!", self.coll_name, self.documents:get_size())
    end
    return SUCCESS, doc
end

function Collection:get_doc(primary_id)
    return self.documents:get(primary_id)
end

--检查存储
function Collection:check_store(now)
    if self.update_count > CACHE_COUNT or self.update_time + CACHE_TIME < now then
        self.update_count = 0
        self.update_time = now
        self:save_all()
    end
end

--更新数据
function Collection:update_field(primary_id, document, field, field_data, flush)
    if not document:update_field(field, field_data, flush) then
        self.dirty_documents[primary_id] = document
    end
    self.update_count = self.update_count + 1
    self.documents:set(primary_id, document)
end

--移除数据
function Collection:remove_field(primary_id, document, field, flush)
    if not document:remove_field(field, flush) then
        self.dirty_documents[primary_id] = document
    end
    self.update_count = self.update_count + 1
    self.documents:set(primary_id, document)
end

--删除数据
function Collection:delete(primary_id)
    local doc = self.documents:get(primary_id)
    if doc then
        self.dirty_documents[primary_id] = nil
        self.documents:del(primary_id)
        doc:destory()
    end
    log_info("[Collection][delete] collection %s now has %s documents!", self.coll_name, self.documents:get_size())
    return SUCCESS
end

--刷新数据
function Collection:flush(primary_id)
    local document = self.dirty_documents[primary_id]
    if document then
        local ok, code = document:update()
        if qfailed(code, ok) then
            return code
        end
        self.dirty_documents[primary_id] = nil
    else
        document = self.documents:get(primary_id)
    end
    if document then
        document:flush()
    end
    return SUCCESS
end

function Collection:save_all(safe)
    for _, doc in pairs(self.dirty_documents) do
        local ok = doc:update()
        if not ok and safe then
            log_err("[Collection][save_all] save mongo failed. try save file")
        end
    end
    self.dirty_documents = {}
end

return Collection
