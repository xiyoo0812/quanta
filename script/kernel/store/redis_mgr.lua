--redis_mgr.lua
local tinsert       = table.insert
local tconcat       = table.concat
local sformat       = string.format
local hash_code     = utility.hash_code

local DBGroup       = enum("DBGroup")
local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local REDIS_FAILED  = KernCode.REDIS_FAILED

local config_mgr    = quanta.get("config_mgr")

local RedisMgr = class()
local prop = property(RedisMgr)
prop:accessor("hash_mode", false)   -- hash_mode
prop:accessor("redis_dbs", {})      -- redis_dbs

function RedisMgr:__init(group)
    self:setup(group)
    self.hash_mode = (group == DBGroup.HASH)
end

--初始化
function RedisMgr:setup(group)
    local RedisDB = import("driver/redis.lua")
    local database = config_mgr:init_table("database", "group", "index")
    for _, conf in database:iterator() do
        if group == conf.group and conf.driver == "redis" then
            self.redis_dbs[conf.index] = RedisDB(conf)
        end
    end
end

--查找redis db
function RedisMgr:get_db(index)
    if self.hash_mode then
        local hash_index = hash_code(index, #self.redis_dbs)
        return self.redis_dbs[hash_index]
    end
    return self.redis_dbs[index]
end

local function format_insert(args)
    local keys = {}
    local values = {}
    for key, value in pairs(args) do
        tinsert(keys, key)
        tinsert(values, value)
    end
    return sformat("(%s) values (%s)", tconcat(keys, ","), tconcat(values, ","))
end

local function format_update(selector, sep)
    local fmt_selector = {}
    for key, value in pairs(selector) do
        tinsert(fmt_selector, sformat("%s=%s", key, value))
    end
    return tconcat(fmt_selector, ",")
end

local function format_selector(selector, sep)
    local fmt_selector = {}
    for key, value in pairs(selector) do
        if key == "$and" then
            tinsert(fmt_selector, format_selector(value))
        elseif key == "$or" then
            tinsert(fmt_selector, format_selector(value, " or "))
        elseif type(value) == "table" then
            local lkey = next(value)
            if lkey then
                if lkey == "$lt" then
                    tinsert(fmt_selector, sformat("%s<%s", key, value[lkey]))
                elseif lkey == "$lte" then
                    tinsert(fmt_selector, sformat("%s<=%s", key, value[lkey]))
                elseif lkey == "$gt" then
                    tinsert(fmt_selector, sformat("%s>%s", key, value[lkey]))
                elseif lkey == "$gte" then
                    tinsert(fmt_selector, sformat("%s>=%s", key, value[lkey]))
                elseif lkey == "$ne" then
                    tinsert(fmt_selector, sformat("%s!=%s", key, value[lkey]))
                end
            end
        else
            tinsert(fmt_selector, sformat("%s=%s", key, value))
        end
    end
    return sformat("(%s)", tconcat(fmt_selector, sep or " and "))
end

local function format_fields(fields)
    local ignores = {}
    local fmt_fields = {}
    for k, v in pairs(fields or {}) do
        if v == 1 then
            tinsert(fmt_fields, k)
        else
            ignores[k] = true
        end
    end
    if #fmt_fields == 0 then
        return "*", ignores
    end
    return tconcat(fmt_fields, ","), ignores
end

local function format_table_fields(fields)
    local table_fields = {}
    for field_name, field_type in pairs(fields) do
        tinsert(table_fields, sformat("%s %s", field_name, field_type))
    end
    return tconcat(table_fields, ",")
end

function RedisMgr:create_table(index, coll_name, fields)
    local redisdb = self:get_db(index)
    if redisdb then
        local fmt = "create table %s (_id int auto_increment, %s, primary key (_id))"
        local sql = sformat(fmt, coll_name, format_table_fields(fields))
        local ok, res_oe = redisdb:query(sql)
        return ok and SUCCESS or REDIS_FAILED, res_oe
    end
    return REDIS_FAILED, "redis db not exist"
end

function RedisMgr:find(index, coll_name, selector, fields, limit)
    local redisdb = self:get_db(index)
    if redisdb then
        local fiels_str, ignores = format_fields(fields)
        local sql = sformat("select %s from %s where %s", fiels_str, coll_name, format_selector(selector))
        if limit then
            sql = sformat("%s limit %d", sql, limit)
        end
        local ok, res_oe = redisdb:query(sql, ignores)
        return ok and SUCCESS or REDIS_FAILED, res_oe
    end
    return REDIS_FAILED, "redis db not exist"
end

function RedisMgr:collect(coll_name, selector, fields, limit)
    local collect_res = {}
    if limit then
        local fiels_str, ignores = format_fields(fields)
        local sql = sformat("select %s from %s where %s", fiels_str, coll_name, format_selector(selector))
        if limit then
            sql = sformat("%s limit %d", sql, limit)
        end
        for _, redisdb in pairs(self.redis_dbs) do
            local ok, res_oe = redisdb:query(sql, ignores)
            if ok then
                for _, record in pairs(res_oe) do
                    if #collect_res > limit then
                        return SUCCESS, collect_res
                    end
                    tinsert(collect_res, record)
                end
            end
        end
    end
    return SUCCESS, collect_res
end

function RedisMgr:find_one(index, coll_name, selector, fields)
    local redisdb = self:get_db(index)
    if redisdb then
        local fiels_str, ignores = format_fields(fields)
        local sql = sformat("select %s from %s where %s limit 1", fiels_str, coll_name, format_selector(selector))
        local ok, res_oe = redisdb:query(sql, ignores)
        if not ok then
            return REDIS_FAILED, res_oe
        end
        return SUCCESS, res_oe[1]
    end
    return REDIS_FAILED, "redis db not exist"
end

function RedisMgr:insert(index, coll_name, obj)
    local redisdb = self:get_db(index)
    if redisdb then
        local sql = sformat("insert into %s %s", coll_name, format_insert(obj))
        local ok, res_oe = redisdb:query(sql)
        return ok and SUCCESS or REDIS_FAILED, res_oe
    end
    return REDIS_FAILED, "redis db not exist"
end

function RedisMgr:update(index, coll_name, obj, selector, upsert, multi)
    local redisdb = self:get_db(index)
    if redisdb then
        local sql = sformat("update %s set %s where %s", coll_name, format_update(obj), format_selector(selector))
        local ok, res_oe = redisdb:query(sql)
        return ok and SUCCESS or REDIS_FAILED, res_oe
    end
    return REDIS_FAILED, "redis db not exist"
end

function RedisMgr:delete(index, coll_name, selector, onlyone)
    local redisdb = self:get_db(index)
    if redisdb then
        local sql = sformat("delete from %s where %s", coll_name, format_selector(selector))
        if onlyone then
            sql = sformat("%s limit 1", sql)
        end
        local ok, res_oe = redisdb:query(sql)
        return ok and SUCCESS or REDIS_FAILED, res_oe
    end
    return REDIS_FAILED, "redis db not exist"
end

function RedisMgr:count(index, coll_name, selector, limit, skip)
    local redisdb = self:get_db(index)
    if redisdb then
        local sql = sformat("select count(*) as count from %s where %s", coll_name, format_selector(selector))
        local ok, res_oe = redisdb:query(sql)
        if not ok then
            return REDIS_FAILED, res_oe
        end
        return SUCCESS, res_oe[1].count
    end
    return REDIS_FAILED, "redis db not exist"
end

--local tt = {key3 = 3, ["$or"]={key1=11, key2={["$lt"]=22}}}
--local test = sformat("select count(*) as count from %s where %s", coll_name, format_selector(tt))
--print("test", test)

return RedisMgr
