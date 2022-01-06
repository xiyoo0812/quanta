--mysql_agent.lua
local mrandom       = math.random
local sformat       = string.format
local tinsert       = table.insert
local tconcat       = table.concat

local KernCode      = enum("KernCode")

local router_mgr    = quanta.get("router_mgr")

local MysqlAgent = singleton()
function MysqlAgent:__init()
end

function MysqlAgent:format(value)
    if type(value) == 'string' then
        return sformat("'%s'", value)
    end
    return value
end

function MysqlAgent:format_condition_sql(conditions)
    local condition_sqls = {}
    for key, value in pairs(conditions) do
        tinsert(condition_sqls, sformat("%s=%s", key, self:format(value)))
    end
    return tconcat(condition_sqls, " and ")
end

function MysqlAgent:format_update_sql(columns)
    local valuess = {}
    for key, value in pairs(columns) do
        tinsert(valuess, sformat("%s=%s", key, self:format(value)))
    end
    return tconcat(valuess, ",")
end

function MysqlAgent:format_insert_sql(columns)
    local keys, values = {}, {}
    for key, value in pairs(columns) do
        tinsert(keys, key)
        tinsert(values, self:format(value))
    end
    return sformat("(%s) values (%s)", tconcat(keys, ","), tconcat(values, ","))
end

function MysqlAgent:format_query_sql(fields)
    return tconcat(fields, ",")
end

-- 更新
function MysqlAgent:update(db_name, table_name, columns, conditions)
    if not next(columns) or not next(conditions) then
        return false, KernCode.PARAM_ERROR
    end
    local sql = sformat("update %s set %s where %s", table_name, self:format_update_sql(columns), self:format_condition_sql(conditions))
    return self:excute(sql, db_name)
end

-- 插入
function MysqlAgent:insert(db_name, table_name, columns)
    if not next(columns) then
        return false, KernCode.PARAM_ERROR
    end
    local sql = sformat("insert into %s %s", table_name, self:format_insert_sql(columns))
    return self:excute(sql, db_name)
end

-- 重复插入(存在则更新，不存在则插入)
function MysqlAgent:insert_or_update(db_name, table_name, columns)
    if not next(columns) then
        return false, KernCode.PARAM_ERROR
    end
    local sql = sformat("insert into %s %s on duplicate key update %s", table_name, self:format_insert_sql(columns), self:format_update_sql(columns))
    return self:excute(sql, db_name)
end

-- 替换
function MysqlAgent:replace(db_name, table_name, columns)
    if not next(columns) then
        return false, KernCode.PARAM_ERROR
    end
    local sql = sformat("replace into %s %s", table_name, self:format_insert_sql(columns))
    return self:excute(sql, db_name)
end

-- 查询
function MysqlAgent:query(db_name, table_name, conditions, fields)
    local query_sql = "*"
    if fields and #fields > 0 then
        query_sql = self:format_query_sql(fields)
    end
    if conditions and next(conditions) then
        -- 带条件查询
        local sql = sformat("select %s from %s where %s", table_name, query_sql, self:format_condition_sql(conditions))
        return self:excute(sql, db_name)
    else
        -- 不带条件查询
        local sql = sformat("select %s from %s", table_name, query_sql)
        return self:excute(sql, db_name)
    end
end

-- 删除
function MysqlAgent:delete(db_name, table_name, conditions)
    if not next(conditions) then
        return false, KernCode.PARAM_ERROR
    end
    local sql = sformat("delete from %s where %s", table_name, self:format_condition_sql(conditions))
    return self:excute(sql, db_name)
end

-- 清空整张表
function MysqlAgent:truncate(db_name, table_name)
    local sql = sformat("truncate table %s", table_name)
    return self:excute(sql, db_name)
end

--发送数据库请求
function MysqlAgent:execute(sql, db_name, hash_key)
    return router_mgr:call_mysql_hash(hash_key or mrandom(10000), "mysql_execute", db_name or "default", sql)
end

------------------------------------------------------------------
quanta.mysql_agent = MysqlAgent()

return MysqlAgent
