--mongo_agent.lua
local tunpack           = table.unpack

local router_mgr        = quanta.get("router_mgr")

local MongoAgent = singleton()
function MongoAgent:__init()
end

--db_query: {coll_name, selector, fields}
function MongoAgent:find_one(hash_key, db_query, db_name)
    return router_mgr:call_mongo_hash(hash_key, "mongo_find_one", db_name or "default", tunpack(db_query))
end

--db_query: {coll_name, selector, fields, sortor, limit}
function MongoAgent:find(hash_key, db_query, db_name)
    return router_mgr:call_mongo_hash(hash_key, "mongo_find", db_name or "default", tunpack(db_query))
end

--db_query: {coll_name, selector, single}
function MongoAgent:delete(hash_key, db_query, db_name)
    return router_mgr:call_mongo_hash(hash_key, "mongo_delete", db_name or "default", tunpack(db_query))
end

--db_query: {coll_name, obj, selector, upsert, multi}
function MongoAgent:update(hash_key, db_query, db_name)
    return router_mgr:call_mongo_hash(hash_key, "mongo_update", db_name or "default", tunpack(db_query))
end

--db_query: {coll_name, obj}
function MongoAgent:insert(hash_key, db_query, db_name)
    return router_mgr:call_mongo_hash(hash_key, "mongo_insert", db_name or "default", tunpack(db_query))
end

--db_query: {coll_name, selector}
function MongoAgent:count(hash_key, db_query, db_name)
    return router_mgr:call_mongo_hash(hash_key, "mongo_count", db_name or "default", tunpack(db_query))
end

--db_query: {coll_name, indexes}
function MongoAgent:create_indexes(hash_key, db_query, db_name)
    return router_mgr:call_mongo_hash(hash_key, "mongo_create_indexes", db_name or "default", tunpack(db_query))
end

--db_query: {coll_name, index_name}
function MongoAgent:drop_indexes(hash_key, db_query, db_name)
    return router_mgr:call_mongo_hash(hash_key, "mongo_drop_indexes", db_name or "default", tunpack(db_query))
end

--db_query: {cmd, ...}
function MongoAgent:execute(hash_key, db_query, db_name)
    return router_mgr:call_mongo_hash(hash_key, "mongo_execute", db_name or "default", tunpack(db_query))
end
------------------------------------------------------------------
quanta.mongo_agent = MongoAgent()

return MongoAgent
