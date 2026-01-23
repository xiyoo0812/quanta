-- document.lua
local log_err       = logger.err
local qfailed       = quanta.failed
local deepcopy      = table.deepcopy

local kvdriver      = quanta.get("smdb")
local mongo_mgr     = quanta.get("mongo_mgr")
local cache_mgr     = quanta.get("cache_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local Document = class()
local prop = property(Document)
prop:reader("coll_name", nil)       -- table name
prop:reader("primary_key", nil)     -- primary key
prop:reader("primary_id", nil)      -- primary id
prop:reader("prototype", nil)       -- prototype
prop:reader("increases", {})        -- increases
prop:reader("wholes", {})           -- wholes
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
end

function Document:get(key)
    return self.wholes[key]
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
    local query = { [self.primary_key] = self.primary_id }
    local code, res = mongo_mgr:find_one(self.primary_id, self.coll_name, query, { _id = 0 })
    if qfailed(code) then
        log_err("[Document][load] failed: {}=> table: {}", res, self.coll_name)
        return code
    end
    self.wholes = res or {}
    return self:merge()
end

function Document:merge_document(src, dst)
    if not dst or type(dst) ~= "table" then dst = {} end
    for key, value in pairs(src or {}) do
        if value == "nil" then
            dst[key] = nil
        elseif (type(value) == "table") then
            dst[key] = self:merge_document(value, dst[key])
        else
            dst[key] = value
        end
    end
    return dst
end

--合并
function Document:merge()
    local increases = kvdriver:get(self.primary_id, self.coll_name)
    if next(increases) then
        self:merge_document(increases, self.wholes)
        self.increases = increases
    end
    self:check_flush()
    return SUCCESS
end

--删除数据
function Document:destory()
    local query = { [self.primary_key] = self.primary_id }
    local code, res = mongo_mgr:delete(self.primary_id, self.coll_name, query, true)
    if qfailed(code) then
        log_err("[Document][destory] del failed: {}=> table: {}", res, self.coll_name)
        return false, code
    end
    kvdriver:del(self.primary_id, self.coll_name)
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
    --存储DB
    local increases = self.increases
    local primary_id = self:check_primary()
    local selector = { [self.primary_key] = primary_id }
    self.increases = {}
    local code, res = mongo_mgr:update(primary_id, self.coll_name, self.wholes, selector, true)
    if qfailed(code) then
        log_err("[Document][update] update failed: {}=> table: {}", res, self.coll_name)
        self:rollback(increases)
        return false, code
    end
    --检查新缓存
    if not next(self.increases) then
        --删除缓存
        kvdriver:del(self.primary_id, self.coll_name)
    end
    return true, SUCCESS
end

--全量更新
function Document:update_wholes(wholes)
    self.wholes = wholes
    self:flush()
end

--回滚提交
function Document:rollback(increases)
    if next(self.increases) then
        deepcopy(self.increases, increases)
        kvdriver:put(self.primary_id, increases, self.coll_name)
    end
    self.increases = increases
    -- 5 秒后重试
    self.time = quanta.now + 5
end

--增量更新
function Document:update_increases(increases)
    deepcopy(increases, self.increases)
    self:merge_document(increases, self.wholes)
    kvdriver:put(self.primary_id, self.increases, self.coll_name)
    self:check_flush()
end

function Document:check_flush(force)
    self.count = self.count - 1
    if self.count <= 0 or self.time < quanta.now or force then
        --重置时间和次数
        self.time = quanta.now + self.prototype.time
        self.count = self.prototype.count
        --存在增量更新
        if next(self.increases) then
            self:flush()
        end
    end
end

--全量存储
function Document:flush()
    cache_mgr:save_doc(self)
end

return Document
