--mongo_agent.lua
local tunpack       = table.unpack

local router_mgr    = quanta.router_mgr

local MongoProxy = singleton()
function MongoProxy:__init()
end

--发送数据库请求
--{coll_name, selector, fields}
function MongoProxy:find_one(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_find_one", dbid or 1, tunpack(mongo_query))
end

--发送数据库请求
--{coll_name, selector, fields, sorts, limit}
function MongoProxy:find(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_find", dbid or 1, tunpack(mongo_query))
end

--{coll_name, selector, single}
function MongoProxy:delete(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_delete", dbid or 1, tunpack(mongo_query))
end

--{coll_name, obj, selector, upsert, multi}
function MongoProxy:update(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_update", dbid or 1, tunpack(mongo_query))
end

--{coll_name, obj}
function MongoProxy:insert(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_insert", dbid or 1, tunpack(mongo_query))
end

--{coll_name, selector}
function MongoProxy:count(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_count", dbid or 1, tunpack(mongo_query))
end

--{coll_name, pipeline}
function MongoProxy:aggregate(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_aggregate", dbid or 1, tunpack(mongo_query))
end

------------------------------------------------------------------
quanta.mongo_agent = MongoProxy()

return MongoProxy
