-- document.lua

local log_err       = logger.err
local qfailed       = quanta.failed
local qmerge        = qtable.merge
local tclone        = qtable.deep_copy
local sformat       = string.format
local mrandom       = math.random

local redis_mgr     = quanta.get("redis_mgr")
local mongo_mgr     = quanta.get("mongo_mgr")
local event_mgr     = quanta.get("event_mgr")
local cache_mgr     = quanta.get("cache_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local CLUSTER       = environ.get("QUANTA_CLUSTER")

local Document = class()
local prop = property(Document)
prop:reader("coll_name", nil)       -- table name
prop:reader("primary_key", nil)     -- primary key
prop:reader("primary_id", nil)      -- primary id
prop:reader("prototype", nil)       -- prototype
prop:reader("flushing", false)      -- flushing
prop:reader("hotkey", "")           -- hotkey
prop:reader("increases", {})        -- increases
prop:reader("datas", {})            -- datas
prop:reader("count", 0)             -- count
prop:reader("time", 0)              -- time

--构造函数
function Document:__init(conf, primary_id)
    self.prototype = conf
    self.count = conf.count
    self.coll_name = conf.sheet
    self.primary_key = conf.key
    self.primary_id  = primary_id
    self.time = conf.time + quanta.now
    self.hotkey = sformat("QUANTA:%s:CACHE:%s:%s", CLUSTER, conf.sheet, primary_id)
end

function Document:get(key)
    return self.datas[key]
end

--从数据库加载
function Document:load()
    local query = { [self.primary_key] = self.primary_id }
    local code, res = mongo_mgr:find_one(self.primary_id, self.coll_name, query, { _id = 0 })
    if qfailed(code) then
        log_err("[Document][load] failed: {}=> table: {}", res, self.coll_name)
        return code
    end
    return self:merge(res or {})
end

--合并
function Document:merge(datas)
    local code, res = redis_mgr:execute("GET", self.hotkey)
    if qfailed(code) then
        log_err("[Document][merge] failed: {}=> table: {}", res, self.coll_name)
        return code
    end
    if res then
        self.increases = res
        self.count = self.count - 1
        qmerge(datas, res, "null")
        self:check_primary(datas, self.primary_key)
    end
    self.datas = datas
    local conf = self.prototype
    self.time = quanta.now + mrandom(0, conf.time // 2)
    self.count = self.count - mrandom(0, conf.count // 2)
    self:check_flush()
    return SUCCESS
end

--删除数据
function Document:destory()
    self.datas = {}
    local query = { [self.primary_key] = self.primary_id }
    local code, res = mongo_mgr:delete(self.primary_id, self.coll_name, query, true)
    if qfailed(code) then
        log_err("[Document][destory] del failed: {}=> table: {}", res, self.coll_name)
        return false, code
    end
    local rcode, rres = redis_mgr:execute("DEL", self.hotkey)
    if qfailed(rcode) then
        log_err("[Document][destory] del failed: {}=> hotkey: {}", rres, self.hotkey)
        return false, code
    end
    return true, SUCCESS
end

--复制数据
function Document:copy(datas)
    local copy_data = tclone(datas)
    copy_data[self.primary_key] = self.primary_id
    self.datas = copy_data
    self:update()
end

--保存数据库
function Document:update()
    self.flushing = false
    --存储DB
    self:check_primary(self.datas, self.primary_key)
    local selector = { [self.primary_key] = self.primary_id }
    local code, res = mongo_mgr:update(self.primary_id, self.coll_name, self.datas, selector, true)
    if qfailed(code) then
        log_err("[Document][update] update failed: {}=> table: {}", res, self.coll_name)
        return false, code
    end
    self.increases = {}
    --清理缓存
    local rcode, rres = redis_mgr:execute("DEL", self.hotkey)
    if qfailed(rcode) then
        log_err("[Document][update] del failed: {}=> hotkey: {}", rres, self.hotkey)
        return false, rcode
    end
    --重置时间和次数
    local conf = self.prototype
    self.time = quanta.now + conf.time
    self.count = conf.count
    return true, SUCCESS
end

function Document:update_data(datas, flush)
    --合并数据
    qmerge(self.datas, datas, "null")
    qmerge(self.increases, datas)
    --提交数据库
    if self.flushing then
        return
    end
    if flush then
        self:flush()
        return
    end
    event_mgr:publish_frame(self, "cmomit_redis")
end

--确保有主键
function Document:check_primary(datas, primary_key)
    if not datas[primary_key] then
        datas[primary_key] = self.primary_id
    end
end

--记录缓存
function Document:cmomit_redis()
    local code, res = redis_mgr:execute("SET", self.hotkey, self.increases)
    if qfailed(code) then
        log_err("[Document][cmomit_redis] failed: {}=> hotkey: {}", res, self.hotkey)
        self:flush()
        return
    end
    self:check_flush()
end

function Document:check_flush()
    self.count = self.count - 1
    if self.count <= 0 or self.time < quanta.now then
        self:flush()
    end
end

--全量存储
function Document:flush()
    if self.flushing then
        return
    end
    self.flushing = true
    cache_mgr:save_doc(self)
end

return Document
