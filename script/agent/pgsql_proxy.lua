--pgsql_agent.lua
local tconcat       = table.concat
local sformat       = string.format
local mrandom       = qmath.random

local router_mgr    = quanta.get("router_mgr")

local PARAM_ERROR   = quanta.enum("KernCode", "PARAM_ERROR")

--PG 的 on conflict 需要显式冲突目标(主键或唯一索引列), 允许传字符串或数组
local function as_key_list(keys)
    if type(keys) == "string" then
        return { keys }
    end
    return keys or {}
end

local PgsqlAgent = singleton()

function PgsqlAgent:__init()
end

function PgsqlAgent:format(value)
    if type(value) == 'string' then
        return sformat("'%s'", value)
    end
    return value
end

function PgsqlAgent:format_condition_sql(conditions)
    local condition_sqls = {}
    for key, value in pairs(conditions) do
        condition_sqls[#condition_sqls + 1] = sformat("%s=%s", key, self:format(value))
    end
    return tconcat(condition_sqls, " and ")
end

function PgsqlAgent:format_update_sql(columns)
    local valuess = {}
    for key, value in pairs(columns) do
        valuess[#valuess + 1] = sformat("%s=%s", key, self:format(value))
    end
    return tconcat(valuess, ",")
end

function PgsqlAgent:format_insert_sql(columns)
    local keys, values = {}, {}
    for key, value in pairs(columns) do
        keys[#keys + 1] = key
        values[#values + 1] = self:format(value)
    end
    return sformat("(%s) values (%s)", tconcat(keys, ","), tconcat(values, ","))
end

function PgsqlAgent:format_query_sql(fields)
    return tconcat(fields, ",")
end

-- 更新
function PgsqlAgent:update(table_name, columns, conditions)
    if not next(columns) or not next(conditions) then
        return false, PARAM_ERROR
    end
    local sql = sformat("update %s set %s where %s", table_name, self:format_update_sql(columns), self:format_condition_sql(conditions))
    return self:query(sql)
end

-- 插入
function PgsqlAgent:insert(table_name, columns)
    if not next(columns) then
        return false, PARAM_ERROR
    end
    local sql = sformat("insert into %s %s", table_name, self:format_insert_sql(columns))
    return self:query(sql)
end

-- 重复插入(存在则更新，不存在则插入)
-- conflict_keys: 冲突目标, 主键或唯一索引列, 如 "id" 或 {"id","platform_id"}
function PgsqlAgent:insert_or_update(table_name, columns, conflict_keys)
    if not next(columns) then
        return false, PARAM_ERROR
    end
    local keys = as_key_list(conflict_keys)
    if #keys == 0 then
        return false, PARAM_ERROR
    end
    local ignores, updates = {}, {}
    for _, key in ipairs(keys) do
        ignores[key] = true
    end
    for key in pairs(columns) do
        if not ignores[key] then
            updates[#updates + 1] = sformat("%s=excluded.%s", key, key)
        end
    end
    --只有冲突列时退化为 do nothing, 否则按 excluded 更新非冲突列
    local action = "do nothing"
    if #updates > 0 then
        action = sformat("do update set %s", tconcat(updates, ","))
    end
    local sql = sformat("insert into %s %s on conflict (%s) %s",
            table_name, self:format_insert_sql(columns), tconcat(keys, ","), action)
    return self:query(sql)
end

-- 替换(PG 无 replace into, 用 on conflict 全列覆盖模拟)
function PgsqlAgent:replace(table_name, columns, conflict_keys)
    if not next(columns) then
        return false, PARAM_ERROR
    end
    local keys = as_key_list(conflict_keys)
    if #keys == 0 then
        return false, PARAM_ERROR
    end
    local updates = {}
    for key in pairs(columns) do
        updates[#updates + 1] = sformat("%s=excluded.%s", key, key)
    end
    local sql = sformat("insert into %s %s on conflict (%s) do update set %s",
            table_name, self:format_insert_sql(columns), tconcat(keys, ","), tconcat(updates, ","))
    return self:query(sql)
end

-- 条件查询
function PgsqlAgent:select(table_name, conditions, fields)
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
function PgsqlAgent:delete(table_name, conditions)
    if not next(conditions) then
        return false, PARAM_ERROR
    end
    local sql = sformat("delete from %s where %s", table_name, self:format_condition_sql(conditions))
    return self:query(sql)
end

-- 清空整张表
function PgsqlAgent:truncate(table_name)
    local sql = sformat("truncate table %s", table_name)
    return self:query(sql)
end

--发送数据库请求
function PgsqlAgent:query(sql, primary_id)
    local key = primary_id or mrandom()
    return router_mgr:call_pgsql_hash(key, "rpc_pgsql_query", key, sql)
end

--发送数据库请求
function PgsqlAgent:prepare(stmt, sql)
    return router_mgr:call_pgsql_master("rpc_pgsql_prepare", stmt, sql)
end

--发送数据库请求
function PgsqlAgent:execute(primary_id, stmt, ...)
    local key = primary_id or mrandom()
    return router_mgr:call_pgsql_hash(key, "rpc_pgsql_execute", key, stmt, ...)
end

------------------------------------------------------------------
quanta.pgsql_agent = PgsqlAgent()

return PgsqlAgent
