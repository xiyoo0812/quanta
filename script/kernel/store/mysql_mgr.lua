--mysql_mgr.lua
local tinsert       = table.insert
local tconcat       = table.concat
local sformat       = string.format
local hash_code     = utility.hash_code

local DBGroup       = enum("DBGroup")
local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local MYSQL_FAILED  = KernCode.MYSQL_FAILED

local config_mgr    = quanta.get("config_mgr")

local MysqlMgr = class()
local prop = property(MysqlMgr)
prop:accessor("hash_mode", false)   -- hash_mode
prop:accessor("mysql_dbs", {})      -- mysql_dbs

function MysqlMgr:__init(group)
    self:setup(group)
    self.hash_mode = (group == DBGroup.HASH)
end

--初始化
function MysqlMgr:setup(group)
    local MysqlDB = import("driver/mysql.lua")
    local database = config_mgr:init_table("database", "group", "index")
    for _, conf in database:iterator() do
        if group == conf.group and conf.driver == "mysql" then
            self.mysql_dbs[conf.index] = MysqlDB(conf)
        end
    end
end

--查找mysql db
function MysqlMgr:get_db(index)
    if self.hash_mode then
        local hash_index = hash_code(index, #self.mysql_dbs)
        return self.mysql_dbs[hash_index]
    end
    return self.mysql_dbs[index]
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

local function format_selector(selector)
    local fmt_selector = {}
    for key, value in pairs(selector) do
        tinsert(fmt_selector, sformat("%s=%s", key, value))
    end
    return tconcat(fmt_selector, "and")
end

local function format_fields(fields)
    if not fields or #fields == 0 then
        return "*"
    end
    local fmt_fields = {}
    for k in pairs(fields) do
        tinsert(fmt_fields, k)
    end
    return tconcat(fmt_fields, ",")
end

local function format_table_fields(fields)
    local table_fields = {}
    for field_name, field_type in pairs(fields) do
        tinsert(table_fields, sformat("%s %s", field_name, field_type))
    end
    return tconcat(table_fields, ",")
end

function MysqlMgr:create_table(index, coll_name, fields)
    local mysqldb = self:get_db(index)
    if mysqldb then
        local fmt = "create table %s (_id int auto_increment, %s, primary key (_id))"
        local sql = sformat(fmt, coll_name, format_table_fields(fields))
        local ok, res_oe = mysqldb:query(sql)
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

function MysqlMgr:find(index, coll_name, selector, fields, limit)
    local mysqldb = self:get_db(index)
    if mysqldb then
        local sql = sformat("select %s from %s while %s", format_fields(fields), coll_name, format_selector(selector))
        if limit then
            sql = sformat("%s limit %d", sql, limit)
        end
        local ok, res_oe = mysqldb:query(sql)
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

function MysqlMgr:collect(coll_name, selector, fields, limit)
    local collect_res = {}
    if limit then
        for _, mysqldb in pairs(self.mysql_dbs) do
            local ok, res_oe = mysqldb:find(coll_name, selector, fields, limit)
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

function MysqlMgr:find_one(index, coll_name, selector, fields)
    local mysqldb = self:get_db(index)
    if mysqldb then
        local sql = sformat("select %s from %s while %s limit 1", format_fields(fields), coll_name, format_args(selector))
        local ok, res_oe = mysqldb:query(sql)
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

function MysqlMgr:insert(index, coll_name, obj)
    local mysqldb = self:get_db(index)
    if mysqldb then
        local sql = sformat("insert into %s %s", coll_name, format_insert(obj))
        local ok, res_oe = mysqldb:query(sql)
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

function MysqlMgr:update(index, coll_name, obj, selector, upsert, multi)
    local mysqldb = self:get_db(index)
    if mysqldb then
        local sql = sformat("update %s set %s where %s", coll_name, format_selector(obj), format_selector(selector))
        local ok, res_oe = mysqldb:query(sql)
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

function MysqlMgr:delete(index, coll_name, selector, onlyone)
    local mysqldb = self:get_db(index)
    if mysqldb then
        local ok, res_oe = mysqldb:delete(coll_name, selector, onlyone)
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

function MysqlMgr:count(index, coll_name, selector, limit, skip)
    local mysqldb = self:get_db(index)
    if mysqldb then
        local ok, res_oe = mysqldb:count(coll_name, selector, limit, skip)
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

return MysqlMgr
