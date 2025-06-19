--mongo_agent.lua
local tunpack       = table.unpack
local mrandom       = qmath.random

local router_mgr    = quanta.get("router_mgr")

local MongoAgent = singleton()

function MongoAgent:__init()
end

--db_query: {coll_name, selector, fields}
function MongoAgent:find_one(db_query, hash_key)
    local key = hash_key or mrandom()
    return router_mgr:call_mongo_hash(key, "rpc_mongo_find_one", key, tunpack(db_query))
end

--db_query: {coll_name, selector, fields, sortor, limit}
function MongoAgent:find(db_query, hash_key)
    local key = hash_key or mrandom()
    return router_mgr:call_mongo_hash(key, "rpc_mongo_find", key, tunpack(db_query))
end

--db_query: {coll_name, selector, single}
function MongoAgent:delete(db_query, hash_key)
    local key = hash_key or mrandom()
    return router_mgr:call_mongo_hash(key, "rpc_mongo_delete", key, tunpack(db_query))
end

--db_query: {coll_name, obj, selector, upsert, multi}
function MongoAgent:update(db_query, hash_key)
    local key = hash_key or mrandom()
    return router_mgr:call_mongo_hash(key, "rpc_mongo_update", key, tunpack(db_query))
end

--db_query: {coll_name, obj}
function MongoAgent:insert(db_query, hash_key)
    local key = hash_key or mrandom()
    return router_mgr:call_mongo_hash(key, "rpc_mongo_insert", key, tunpack(db_query))
end

--db_query: {coll_name, update, selector, upsert, fields, new}
function MongoAgent:find_and_modify(db_query, hash_key)
    local key = hash_key or mrandom()
    return router_mgr:call_mongo_hash(key, "rpc_mongo_find_and_modify", key, tunpack(db_query))
end

--db_query: {coll_name, pipeline, { [xxkey, xxvalue], ...}
function MongoAgent:aggregate(db_query, hash_key)
    local key = hash_key or mrandom()
    return router_mgr:call_mongo_hash(key, "rpc_mongo_aggregate", key, tunpack(db_query))
end

--db_query: {datas, ordered, { [xxkey, xxvalue], ...}
function MongoAgent:bulkwrite(db_query, hash_key)
    local key = hash_key or mrandom()
    return router_mgr:call_mongo_hash(key, "rpc_mongo_bulkwrite", key, tunpack(db_query))
end

--db_query: {coll_name, selector}
function MongoAgent:count(db_query, hash_key)
    return router_mgr:call_mongo_hash(hash_key or mrandom(), "rpc_mongo_count", tunpack(db_query))
end

--db_query: {coll_name, indexes}
function MongoAgent:create_indexes(db_query, hash_key)
    return router_mgr:call_mongo_hash(hash_key or mrandom(), "rpc_mongo_create_indexes", tunpack(db_query))
end

--db_query: {coll_name, index_name}
function MongoAgent:drop_indexes(db_query, hash_key)
    return router_mgr:call_mongo_hash(hash_key or mrandom(), "rpc_mongo_drop_indexes", tunpack(db_query))
end

function MongoAgent:autoinc_id(id_key)
    return router_mgr:call_mongo_hash(mrandom(), "rpc_mongo_autoinc_id", id_key)
end

--db_query: {cmd, ...}
function MongoAgent:execute(db_query, hash_key)
    local key = hash_key or mrandom()
    return router_mgr:call_mongo_hash(key, "rpc_mongo_execute", key, tunpack(db_query))
end

------------------------------------------------------------------
quanta.mongo_agent = MongoAgent()

return MongoAgent
