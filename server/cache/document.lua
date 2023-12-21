-- document.lua

local log_err       = logger.err
local qfailed       = quanta.failed
local qkeys         = qtable.keys
local qunfold       = qtable.unfold
local tclone        = qtable.deep_copy
local sstart        = qstring.start_with
local sformat       = string.format
local tunpack       = table.unpack
local tconcat       = table.concat
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
prop:reader("hmsets", {})           -- hmsets
prop:reader("wholes", {})           -- wholes
prop:reader("indexs", {})           -- indexs
prop:reader("hdels", {})            -- hdels
prop:reader("hotkey", "")           -- hotkey
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
    return self.wholes[key]
end

--确保有主键
function Document:check_primary()
    if not self.wholes[self.primary_key] then
        self.wholes[self.primary_key] = self.primary_id
    end
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

--合并
function Document:merge()
    local code, res = redis_mgr:execute("HGETALL", self.hotkey)
    if qfailed(code) then
        log_err("[Document][merge] failed: {}=> table: {}", res, self.coll_name)
        return code
    end
    if next(res) then
        for field, field_data in pairs(res) do
            self.indexs[field] = true
            local cur_data = self.wholes
            local pkeys, size = cache_mgr:build_fields(field)
            for i = 1, size - 1 do
                local cfield = pkeys[i]
                if not cur_data[cfield] then
                    cur_data[cfield] = {}
                end
                cur_data = cur_data[cfield]
            end
            local value = field_data[1]
            cur_data[pkeys[size]] = (value ~= "nil") and value or nil
            self.count = self.count - 1
        end
    end
    self.time = quanta.now + mrandom(0, self.prototype.time // 2)
    self.count = self.count - mrandom(0, self.prototype.count // 2)
    self:check_flush()
    return SUCCESS
end

--删除数据
function Document:destory()
    self.wholes = {}
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
    self.wholes = copy_data
    self:update()
end

--保存数据库
function Document:update()
    self.flushing = false
    --存储DB
    self:check_primary()
    local selector = { [self.primary_key] = self.primary_id }
    local code, res = mongo_mgr:update(self.primary_id, self.coll_name, self.wholes, selector, true)
    if qfailed(code) then
        log_err("[Document][update] update failed: {}=> table: {}", res, self.coll_name)
        return false, code
    end
    --清理缓存
    self.indexs, self.hmsets, self.hdels = {}, {}, {}
    local rcode, rres = redis_mgr:execute("DEL", self.hotkey)
    if qfailed(rcode) then
        log_err("[Document][update] del failed: {}=> hotkey: {}", rres, self.hotkey)
        return false, rcode
    end
    --重置时间和次数
    self.time = quanta.now + self.prototype.time
    self.count = self.prototype.count
    return true, SUCCESS
end

--全量更新
function Document:update_wholes(wholes)
    self.wholes = wholes
    self:flush()
end

--增量更新
function Document:update_commits(commits)
    for _, commit in ipairs(commits) do
        self:merge_commit(commit)
    end
    --提交数据库
    if self.flushing then
        return
    end
    event_mgr:publish_frame(self, "cmomit_redis")
end

function Document:update_commit(commit)
    self:merge_commit(commit)
    --提交数据库
    if self.flushing then
        return
    end
    event_mgr:publish_frame(self, "cmomit_redis")
end

--合并提交
function Document:merge_commit(commit)
    local cur_data = self.wholes
    local pkeys, field, cvalues, full = tunpack(commit, 1, 4)
    for _, cfield in ipairs(pkeys) do
        if not cur_data[cfield] then
            cur_data[cfield] = {}
        end
        cur_data = cur_data[cfield]
    end
    if full then
        pkeys[#pkeys + 1] = field
        cur_data[field] = (cvalues ~= "nil") and cvalues or nil
        self:build_redis_cache(pkeys, cvalues)
        return
    end
    if field then
        if not cur_data[field] then
            cur_data[field] = {}
        end
        cur_data = cur_data[field]
        pkeys[#pkeys + 1] = field
    end
    for key, value in pairs(cvalues) do
        cur_data[key] = (value ~= "nil") and value or nil
        pkeys[#pkeys + 1] = key
        self:build_redis_cache(pkeys, value)
        pkeys[#pkeys] = nil
    end
end

function Document:build_redis_cache(pkeys, value)
    local ckey = tconcat(pkeys, ".")
    self.indexs[ckey] = true
    self.hmsets[ckey] = {value}
    for rkey in pairs(self.indexs) do
        if #rkey > #ckey then
            if sstart(rkey, ckey .. ".") then
                self.hdels[rkey] = true
                self.indexs[rkey] = nil
                self.hmsets[rkey] = nil
            end
        end
        if #rkey < #ckey then
            if sstart(ckey, rkey .. ".") then
                local cvalue = self.wholes
                local rkeys = cache_mgr:build_fields(rkey)
                for _, cfield in ipairs(rkeys) do
                    cvalue = cvalue[cfield]
                end
                self.hmsets[rkey] = {cvalue or "nil"}
                self.hmsets[ckey] = nil
                self.indexs[ckey] = nil
                self.hdels[ckey] = true
            end
        end
    end
end

--提交redis
function Document:cmomit_redis()
    if next(self.hmsets) then
        local hmsets = self.hmsets
        self.hmsets = {}
        local code, res = redis_mgr:execute("HMSET", self.hotkey, qunfold(hmsets))
        if qfailed(code) then
            log_err("[Document][cmomit_redis] HMSET failed: {}=> hotkey: {}", res, self.hotkey)
            self:flush()
            return
        end
    end
    if next(self.hdels) then
        local hdels = self.hdels
        self.hdels = {}
        local code, res = redis_mgr:execute("HDEL", self.hotkey, qkeys(hdels))
        if qfailed(code) then
            log_err("[Document][cmomit_redis] HDEL failed: {}=> hotkey: {}", res, self.hotkey)
            self:flush()
            return
        end
        self:check_flush()
    end
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
