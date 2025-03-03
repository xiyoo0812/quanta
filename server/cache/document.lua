-- document.lua
local mmin          = math.min
local log_err       = logger.err
local qfailed       = quanta.failed
local tclone        = qtable.deep_copy
local tunpack       = table.unpack
local tinsert       = table.insert

local mongo_mgr     = quanta.get("mongo_mgr")
local event_mgr     = quanta.get("event_mgr")
local cache_mgr     = quanta.get("cache_mgr")
local smdb_driver   = quanta.get("smdb_driver")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local Document = class()
local prop = property(Document)
prop:reader("coll_name", nil)       -- table name
prop:reader("primary_key", nil)     -- primary key
prop:reader("primary_id", nil)      -- primary id
prop:reader("prototype", nil)       -- prototype
prop:reader("flushing", false)      -- flushing
prop:reader("increases", {})        -- increases
prop:reader("commits", {})          -- commits
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

--合并
function Document:merge()
    local commits = smdb_driver:get(self.primary_id, self.coll_name)
    if next(commits) then
        --倒序合并，存储侧使用了倒序提交
        for  i = #commits, 1, -1 do
            self:merge_commit(commits[i])
            self.count = self.count - 10
        end
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
    smdb_driver:del(self.primary_id, self.coll_name)
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
    --存储DB
    local commits = self.increases
    self.flushing, self.increases = true, {}
    local primary_id = self:check_primary()
    local selector = { [self.primary_key] = primary_id }
    local code, res = mongo_mgr:update(primary_id, self.coll_name, self.wholes, selector, true)
    if qfailed(code) then
        log_err("[Document][update] update failed: {}=> table: {}", res, self.coll_name)
        self.flushing = false
        self:rollback(commits)
        return false, code
    end
    --删除缓存
    smdb_driver:del(self.primary_id, self.coll_name)
    --检查新缓存
    self.flushing = false
    if next(self.increases) then
        event_mgr:publish_frame(self, "commit_storage")
    end
    return true, SUCCESS
end

--全量更新
function Document:update_wholes(wholes)
    self.wholes = wholes
    self:flush()
end

--回滚提交
function Document:rollback(commits)
    if next(self.increases) then
        for _, commit in ipairs(self.increases) do
            tinsert(commits, commit)
        end
        event_mgr:publish_frame(self, "commit_storage")
    end
    self.increases = commits
end

--增量更新
function Document:update_commits(commits)
    --倒序合并，发送测使用倒序提交
    for  i = #commits, 1, -1 do
        self:merge_commit(commits[i])
    end
    if not self.flushing then
        --存储请求
        event_mgr:publish_frame(self, "commit_storage")
    end
end

function Document:update_commit(commit)
    self:merge_commit(commit)
    if not self.flushing then
        --存储请求
        event_mgr:publish_frame(self, "commit_storage")
    end
end

--合并提交
function Document:merge_commit(commit)
    local pkeys, key, val, field = tunpack(commit)
    if key and field then
        pkeys[#pkeys + 1] = field
    end
    if not key then
        key = field
    end
    local cur_data = self.wholes
    for _, cfield in ipairs(pkeys) do
        if not cur_data[cfield] then
            cur_data[cfield] = {}
        end
        cur_data = cur_data[cfield]
    end
    cur_data[key] = (val ~= "nil") and val or nil
    --记录增量提交
    tinsert(self.increases, commit)
end

--内部方法
--------------------------------------------------------------
--判断commit是否increase的父节点或者本节点
local function is_parent_or_self(commit, inc_layers, inc_field)
    local clayers, cfield = commit[1], commit[4]
    local len1, len2 = #clayers, #inc_layers
    if len1 > len2 then
        return false
    end
    -- 比较前 n 个元素
    local mix = mmin(len1, len2)
    for i = 1, mix do
        -- 如果元素类型不同或值不同，返回 false
        if clayers[i] ~= inc_layers[i] then
            return false
        end
    end
    if len1 == len2 then
        return cfield == inc_field
    end
    return true
end

--提交本地存储
--倒序合并，cache也需要倒序读取
function Document:commit_storage()
    local commits = {}
    --倒序遍历所有提交
    for i = #self.increases, 1, -1 do
        local increase = self.increases[i]
        --遍历已经合并的提交
        for _, commit in ipairs(commits) do
            --如果commit是increase的父节点或者本节点，则表示increase已经失效，需要丢弃
            if is_parent_or_self(commit, increase[1], increase[4]) then
                goto continue
            end
        end
        --开始提交
        tinsert(commits, increase)
        :: continue ::
    end
    --存储
    smdb_driver:put(self.primary_id, commits, self.coll_name)
    self.commits = commits
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
