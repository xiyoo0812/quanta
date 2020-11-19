--mongo_agent.lua
local tunpack       = table.unpack

local router_mgr    = quanta.router_mgr

local MongoAgent = singleton()
function MongoAgent:__init()
end

--发送数据库请求
--{coll_name, selector, fields}
function MongoAgent:find_one(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_find_one", dbid or 1, tunpack(mongo_query))
end

--发送数据库请求
--{coll_name, selector, fields, sorts, limit}
function MongoAgent:find(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_find", dbid or 1, tunpack(mongo_query))
end

--{coll_name, selector, single}
function MongoAgent:delete(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_delete", dbid or 1, tunpack(mongo_query))
end

--{coll_name, obj, selector, upsert, multi}
function MongoAgent:update(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_update", dbid or 1, tunpack(mongo_query))
end

--{coll_name, obj}
function MongoAgent:insert(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_insert", dbid or 1, tunpack(mongo_query))
end

--{coll_name, selector}
function MongoAgent:count(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_count", dbid or 1, tunpack(mongo_query))
end

--发送数据库请求
--{coll_name, selector, fields}
function MongoAgent:rmsg_find_one(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "rmsg_find_one", dbid or 1, tunpack(mongo_query))
end

--发送数据库请求
--{coll_name, selector, fields, sorts, limit}
function MongoAgent:rmsg_find(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "rmsg_find", dbid or 1, tunpack(mongo_query))
end

--{coll_name, selector, single}
function MongoAgent:rmsg_delete(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "rmsg_delete", dbid or 1, tunpack(mongo_query))
end

--{coll_name, obj, selector, upsert, multi}
function MongoAgent:rmsg_update(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "rmsg_update", dbid or 1, tunpack(mongo_query))
end

--{coll_name, obj}
function MongoAgent:rmsg_insert(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "rmsg_insert", dbid or 1, tunpack(mongo_query))
end

------------------------------------------------------------------
quanta.mongo_agent = MongoAgent()

return MongoAgent
