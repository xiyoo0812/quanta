-- document.lua
local ljson = require("lcjson")

local log_err       = logger.err
local tabmove       = table.move
local tconcat       = table.concat
local qfailed       = quanta.failed
local sformat       = string.format
local ssplit        = qstring.split
local mrandom       = math.random
local convint       = qmath.conv_integer
local makechan      = quanta.make_channel
local json_encode   = ljson.encode
local json_decode   = ljson.decode

local redis_mgr     = quanta.get("redis_mgr")
local mongo_mgr     = quanta.get("mongo_mgr")
local event_mgr     = quanta.get("event_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local NAMESPACE     = environ.get("QUANTA_NAMESPACE")
local MAIN_DBID     = environ.number("QUANTA_DB_MAIN_ID")

local Document = class()
local prop = property(Document)
prop:reader("coll_name", nil)       -- table name
prop:reader("primary_key", nil)     -- primary key
prop:reader("primary_id", nil)      -- primary id
prop:reader("prototype", nil)       -- prototype
prop:reader("depth_max", 1)         -- depth_max
prop:reader("depth_min", 0)         -- depth_min
prop:reader("hotkey", "")           -- hotkey
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
    self.depth_min = conf.depth_min
    self.depth_max = conf.depth_max
    self.time = conf.time + quanta.now
    self.hotkey = sformat("CACHE:%s:%s:%s", NAMESPACE, conf.sheet, primary_id)
end

--从数据库加载
function Document:load()
    local pid = self.primary_id
    local query = { [self.primary_key] = pid }
    local code, res = mongo_mgr:find_one(MAIN_DBID, pid, self.coll_name, query, { _id = 0 })
    if qfailed(code) then
        log_err("[Document][load] failed: %s=> table: %s", res, self.coll_name)
        return code
    end
    self.datas = res or {}
    return self:merge(pid)
end

--合并
function Document:merge(primary_id)
    local code, res = redis_mgr:execute(MAIN_DBID, primary_id, "HGETALL", self.hotkey)
    if qfailed(code) then
        log_err("[Document][merge] failed: %s=> table: %s", res, self.coll_name)
        return code
    end
    if next(res) then
        for key, value in pairs(res) do
            self.count = self.count - 1
            if value == "nil" then
                self:unset_field(key)
            else
                self:set_field(key, json_decode(value))
            end
        end
        local conf = self.prototype
        self.time = quanta.now + mrandom(0, conf.time // 2)
        self.count = self.count - mrandom(0, conf.count // 2)
        self:check_flush()
    end
    return SUCCESS
end

--删除数据
function Document:destory()
    self.datas = {}
    local query = { [self.primary_key] = self.primary_id }
    local code, res = mongo_mgr:delete(MAIN_DBID, self.primary_id, self.coll_name, query, true)
    if qfailed(code) then
        log_err("[Document][destory] del failed: %s=> table: %s", res, self.coll_name)
        return false, code
    end
    local rcode, rres = redis_mgr:execute(MAIN_DBID, self.primary_id, "DEL", self.hotkey)
    if qfailed(rcode) then
        log_err("[Document][destory] del failed: %s=> hotkey: %s", rres, self.hotkey)
        return false, code
    end
    return true, SUCCESS
end

--保存数据库
function Document:update()
    local pid = self.primary_id
    local channel = makechan("doc update")
    channel:push(function()
        local selector = { [self.primary_key] = pid }
        local code, res = mongo_mgr:update(MAIN_DBID, pid, self.coll_name, self.datas, selector, true)
        if qfailed(code) then
            log_err("[Document][update] update failed: %s=> table: %s", res, self.coll_name)
            return false, code
        end
        return true, SUCCESS
    end)
    --清理缓存
    channel:push(function()
        local rcode, rres = redis_mgr:execute(MAIN_DBID, pid, "DEL", self.hotkey)
        if qfailed(rcode) then
            log_err("[Document][update] del failed: %s=> hotkey: %s", rres, self.hotkey)
            return false, rcode
        end
        return true, SUCCESS
    end)
    local ok, code = channel:execute(true)
    if ok then
        --重置时间和次数
        local conf = self.prototype
        self.time = quanta.now + conf.time
        self.count = conf.count
        return true, SUCCESS
    end
    return false, code
end

function Document:update_redis(fields)
    if #fields <= self.depth_min then
        return false
    end
    if #fields > self.depth_max then
        fields = tabmove(fields, 1, self.depth_max, 1, {})
    end
    local key = tconcat(fields, ".")
    local cursor = self.datas
    for _, name in pairs(fields) do
        cursor = cursor[convint(name)]
    end
    event_mgr:fire_next_frame(function()
        if cursor then
            cursor = json_encode(cursor)
        end
        self:cmomit_redis(key, cursor or "nil")
    end)
    return true
end

function Document:update_field(field, field_data)
    if #field > 0 then
        local fields = self:set_field(field, field_data)
        if fields then
            self:update_redis(fields)
        end
    else
        self.datas = field_data
        self:check_primary(self.datas, self.primary_key)
        self:flush()
    end
end

--确保有主键
function Document:check_primary(datas, primary_key)
    if not datas[primary_key] then
        datas[primary_key] = self.primary_id
    end
end

--更新子数据
function Document:set_field(field, field_data)
    local cursor = self.datas
    --检查主键
    self:check_primary(cursor, self.primary_key)
    --设置数值
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
    if cursor[fine_field] ~= field_data then
        cursor[fine_field] = field_data
        return fields
    end
end

function Document:remove_field(field)
    local fields = self:unset_field(field)
    if fields then
        self:update_redis(fields)
    end
end

--删除子数据
function Document:unset_field(field)
    local cursor = self.datas
    --检查主键
    self:check_primary(cursor, self.primary_key)
    --设置数值
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
    if cursor[fine_field] then
        cursor[fine_field] = nil
        return fields
    end
end

--记录缓存
function Document:cmomit_redis(field, value)
    local code, res = redis_mgr:execute(MAIN_DBID, self.primary_id, "HSET", self.hotkey, field, value)
    if qfailed(code) then
        log_err("[Document][cmomit_redis] failed: %s=> hotkey: %s", res, self.hotkey)
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
    event_mgr:notify_listener("on_document_save", self)
end

return Document
