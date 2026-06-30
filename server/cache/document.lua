-- document.lua
local log_err       = logger.err
local qfailed       = quanta.failed
local sformat       = string.format
local deepcopy      = table.deepcopy
local jencode       = json.encode

local mongo_mgr     = quanta.get("mongo_mgr")
local redis_mgr     = quanta.get("redis_mgr")
local cache_mgr     = quanta.get("cache_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local Document = class()
local prop = property(Document)
prop:reader("coll_name", nil)       -- table name
prop:reader("primary_key", nil)     -- primary key
prop:reader("primary_id", nil)      -- primary id
prop:reader("cache_key", nil)       -- cache key
prop:reader("prototype", nil)       -- prototype
prop:reader("wholes", {})           -- wholes
prop:reader("cached", false)        -- cached
prop:reader("count", 0)             -- count
prop:reader("time", 0)              -- time

--构造函数
function Document:__init(conf, primary_id)
    self.prototype = conf
    self.count = conf.count
    self.coll_name = conf.sheet
    self.primary_key = conf.key
    self.primary_id  = primary_id
    self.time = quanta.now + conf.time
    self.cache_key = sformat("QUANTA:CACHE::%s:%s", self.coll_name, self.primary_id)
end

function Document:get(key)
    return self.wholes[key]
end

function Document:load_cache()
    local code, cache = redis_mgr:execute("JSON.GET", self.cache_key)
    if qfailed(code) then
        log_err("[Document][load_cache] get failed: {}=> key: {}", cache, self.cache_key)
        return code
    end
    return SUCCESS, cache
end

function Document:save_cache(path, value)
    local code, res = redis_mgr:execute("JSON.SET", self.cache_key, path, jencode(value))
    if qfailed(code) then
        log_err("[Document][save_cache] set failed: {}=> key: {}", res, self.cache_key)
        return false
    end
    self.cached = true
    return true
end

function Document:clean_cache(path)
    local code, res = redis_mgr:execute("JSON.DEL", self.cache_key, path)
    if qfailed(code) then
        log_err("[Document][clean_cache] del failed: {}=> key: {}, path: {}", res, self.cache_key, path)
        return false
    end
    return true
end

function Document:delete_cache()
    local key = self.cache_key
    local code, res = redis_mgr:execute("DEL", key)
    if qfailed(code) then
        log_err("[Document][delete_cache] del failed: {}=> key: {}", res, key)
        return false
    end
    self.cached = false
    return true
end

--确保有主键
function Document:check_primary()
    if not self.wholes[self.primary_key] then
        self.wholes[self.primary_key] = self.primary_id
    end
    return self.primary_id
end

function Document:load_wholes()
    if next(self.wholes) then
        self:check_primary()
    end
    return self.wholes
end

--从数据库加载
function Document:load()
    local code, cache = self:load_cache()
    if qfailed(code) then
        return code
    end
    if cache then
        self.wholes = cache
        self.cached = true
        return SUCCESS
    end
    local query = { [self.primary_key] = self.primary_id }
    code, cache = mongo_mgr:find_one(self.primary_id, self.coll_name, query, { _id = 0 })
    if qfailed(code) then
        log_err("[Document][load] failed: {}=> table: {}", cache, self.coll_name)
        return code
    end
    self.wholes = cache or {}
    self:check_flush()
    return SUCCESS
end

function Document:merge_document(src, dst)
    local key_path = "$"
    if not self.cached then
        self:save_cache(key_path, self.wholes)
    end
    if not dst or type(dst) ~= "table" then dst = {} end
    for key, value in pairs(src or {}) do
        key_path = sformat("%s.%s", key_path, key)
        if (type(value) == "table") then
            dst[key] = self:merge_document(value, dst[key])
        elseif value == "nil" then
            self:clean_cache(key_path)
            dst[key] = nil
        else
            self:save_cache(key_path, value)
            dst[key] = value
        end
    end
end

--删除数据
function Document:destory()
    local query = { [self.primary_key] = self.primary_id }
    local code, res = mongo_mgr:delete(self.primary_id, self.coll_name, query, true)
    if qfailed(code) then
        log_err("[Document][destory] del failed: {}=> table: {}", res, self.coll_name)
        return false, code
    end
    self:delete_cache()
    return true, SUCCESS
end

--复制数据
function Document:copy(datas)
    local copy_data = deepcopy(datas)
    copy_data[self.primary_key] = self.primary_id
    self.wholes = copy_data
    self:update()
end

--保存数据库
function Document:update()
    local primary_id = self:check_primary()
    local selector = { [self.primary_key] = primary_id }
    local code, res = mongo_mgr:update(primary_id, self.coll_name, self.wholes, selector, true)
    if qfailed(code) then
        log_err("[Document][update] update failed: {}=> table: {}", res, self.coll_name)
        return false, code
    end
    self:save_cache("$", self.wholes)
    return true, SUCCESS
end

--全量更新
function Document:update_wholes(wholes)
    self.wholes = wholes
    self:flush()
end

--增量更新
function Document:update_increases(increases)
    self:merge_document(increases, self.wholes)
    self:check_flush()
end

function Document:check_flush(force)
    self.count = self.count - 1
    if self.count <= 0 or self.time < quanta.now or force then
        --重置时间和次数
        self.time = quanta.now + self.prototype.time
        self.count = self.prototype.count
        --存在缓存更新
        if self.dirty then
            self:flush()
        end
    end
end

--全量存储
function Document:flush()
    cache_mgr:save_doc(self)
end

return Document
