--mongo_agent.lua
local tunpack       = table.unpack

local router_mgr    = quanta.router_mgr

local MongoAgent = singleton()
function MongoAgent:__init()
    self:setup()
end

function MongoAgent:setup()
end

--发送数据库请求
--{coll_name, selector, fields}
function MongoAgent:find_one(hash_key, mongo_query, dbid)
    return router_mgr:call_dbagent_hash(hash_key, "mongo_find_one", dbid or 1, tunpack(mongo_query))
end

--发送数据库请求
--{coll_name, selector, fields, sorts, limit}
function MongoAgent:find(hash_key, mongo_query, dbid)
    return router_mgr:call_dbagent_hash(hash_key, "mongo_find", dbid or 1, tunpack(mongo_query))
end

--{coll_name, selector, single}
function MongoAgent:delete(hash_key, mongo_query, dbid)
    return router_mgr:call_dbagent_hash(hash_key, "mongo_delete", dbid or 1, tunpack(mongo_query))
end

--{coll_name, obj, selector, upsert, multi}
function MongoAgent:update(hash_key, mongo_query, dbid)
    return router_mgr:call_dbagent_hash(hash_key, "mongo_update", dbid or 1, tunpack(mongo_query))
end

--{coll_name, obj}
function MongoAgent:insert(hash_key, mongo_query, dbid)
    return router_mgr:call_dbagent_hash(hash_key, "mongo_insert", dbid or 1, tunpack(mongo_query))
end

------------------------------------------------------------------
quanta.mongo_agent = MongoAgent()

return MongoAgent
