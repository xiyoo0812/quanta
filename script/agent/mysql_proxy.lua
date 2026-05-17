--mysql_proxy.lua
local tconcat       = table.concat
local sformat       = string.format
local mrandom       = qmath.random

local router_mgr    = quanta.get("router_mgr")

local PARAM_ERROR   = quanta.enum("KernCode", "PARAM_ERROR")

local MysqlProxy = singleton()

function MysqlProxy:__init()
end

function MysqlProxy:format(value)
    if type(value) == 'string' then
        return sformat("'%s'", value)
    end
    return value
end

function MysqlProxy:format_condition_sql(conditions)
    local condition_sqls = {}
    for key, value in pairs(conditions) do
        condition_sqls[#condition_sqls + 1] = sformat("%s=%s", key, self:format(value))
    end
    return tconcat(condition_sqls, " and ")
end

function MysqlProxy:format_update_sql(columns)
    local valuess = {}
    for key, value in pairs(columns) do
        valuess[#valuess + 1] = sformat("%s=%s", key, self:format(value))
    end
    return tconcat(valuess, ",")
end

function MysqlProxy:format_insert_sql(columns)
    local keys, values = {}, {}
    for key, value in pairs(columns) do
        keys[#keys + 1] = key
        values[#values + 1] = self:format(value)
    end
    return sformat("(%s) values (%s)", tconcat(keys, ","), tconcat(values, ","))
end

function MysqlProxy:format_query_sql(fields)
    return tconcat(fields, ",")
end

-- 更新
function MysqlProxy:update(table_name, columns, conditions)
    if not next(columns) or not next(conditions) then
        return false, PARAM_ERROR
    end
    local sql = sformat("update %s set %s where %s", table_name, self:format_update_sql(columns), self:format_condition_sql(conditions))
    return self:query(sql)
end

-- 插入
function MysqlProxy:insert(table_name, columns)
    if not next(columns) then
        return false, PARAM_ERROR
    end
    local sql = sformat("insert into %s %s", table_name, self:format_insert_sql(columns))
    return self:query(sql)
end

-- 重复插入(存在则更新，不存在则插入)
function MysqlProxy:insert_or_update(table_name, columns)
    if not next(columns) then
        return false, PARAM_ERROR
    end
    local sql = sformat("insert into %s %s on duplicate key update %s", table_name, self:format_insert_sql(columns), self:format_update_sql(columns))
    return self:query(sql)
end

-- 替换
function MysqlProxy:replace(table_name, columns)
    if not next(columns) then
        return false, PARAM_ERROR
    end
    local sql = sformat("replace into %s %s", table_name, self:format_insert_sql(columns))
    return self:query(sql)
end

-- 查询
function MysqlProxy:query(table_name, conditions, fields)
    local query_sql = "*"
    if fields and #fields > 0 then
        query_sql = self:format_query_sql(fields)
    end
    if conditions and next(conditions) then
        -- 带条件查询
        local sql = sformat("select %s from %s where %s", table_name, query_sql, self:format_condition_sql(conditions))
        return self:query(sql)
    else
        -- 不带条件查询
        local sql = sformat("select %s from %s", table_name, query_sql)
        return self:query(sql)
    end
end

-- 删除
function MysqlProxy:delete(table_name, conditions)
    if not next(conditions) then
        return false, PARAM_ERROR
    end
    local sql = sformat("delete from %s where %s", table_name, self:format_condition_sql(conditions))
    return self:query(sql)
end

-- 清空整张表
function MysqlProxy:truncate(table_name)
    local sql = sformat("truncate table %s", table_name)
    return self:query(sql)
end

--发送数据库请求
function MysqlProxy:query(sql, primary_id)
    local key = primary_id or mrandom()
    return router_mgr:call_mongo_hash(key, "rpc_pgsql_query", key, sql)
end

--发送数据库请求
function MysqlProxy:prepare(stmt, sql)
    return router_mgr:call_mongo_master("rpc_pgsql_prepare", stmt, sql)
end

--发送数据库请求
function MysqlProxy:execute(primary_id, stmt, ...)
    local key = primary_id or mrandom()
    return router_mgr:call_mongo_hash(key, "rpc_pgsql_execute", key, stmt, ...)
end

------------------------------------------------------------------
quanta.mysql_proxy = MysqlProxy()

return MysqlProxy
