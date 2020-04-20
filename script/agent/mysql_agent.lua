--mysql_agent.lua
local router_mgr = quanta.router_mgr

local MysqlAgent = singleton()
function MysqlAgent:__init()
end

--发送数据库请求
function MysqlAgent:find_one(hash_key, sql, dbid)
    return router_mgr:call_dbagent_hash(hash_key, "mysql_find_one", sql, dbid or 1)
end

--发送数据库请求
function MysqlAgent:find(hash_key, sql, dbid)
    return router_mgr:call_dbagent_hash(hash_key, "mysql_find", sql, dbid or 1)
end

function MysqlAgent:delete(hash_key, sql, dbid)
    return router_mgr:call_dbagent_hash(hash_key, "mysql_delete", sql, dbid or 1)
end

function MysqlAgent:update(hash_key, sql, dbid)
    return router_mgr:call_dbagent_hash(hash_key, "mysql_update", sql, dbid or 1)
end

function MysqlAgent:insert(hash_key, sql, dbid)
    return router_mgr:call_dbagent_hash(hash_key, "mysql_insert", sql, dbid or 1)
end

return MysqlAgent
