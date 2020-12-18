--mongo_agent.lua
local tunpack       = table.unpack
local env_number    = environ.number

local router_mgr    = quanta.router_mgr

local GlobalDB      = enum("GlobalDB")

local MongoAgent = singleton()
function MongoAgent:__init()
    self.dbid = env_number("QUANTA_PART_ID")
end

--发送数据库请求
--{coll_name, selector, fields}
function MongoAgent:find_one(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "game_find_one", dbid or self.dbid, tunpack(mongo_query))
end

--发送数据库请求
--{coll_name, selector, fields, sorts, limit}
function MongoAgent:find(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "game_find", dbid or self.dbid, tunpack(mongo_query))
end

--{coll_name, selector, single}
function MongoAgent:delete(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "game_delete", dbid or self.dbid, tunpack(mongo_query))
end

--{coll_name, obj, selector, upsert, multi}
function MongoAgent:update(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "game_update", dbid or self.dbid, tunpack(mongo_query))
end

--{coll_name, obj}
function MongoAgent:insert(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "game_insert", dbid or self.dbid, tunpack(mongo_query))
end

--{coll_name, selector}
function MongoAgent:count(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "game_count", dbid or self.dbid, tunpack(mongo_query))
end

--发送数据库请求
--{coll_name, selector, fields}
function MongoAgent:global_find_one(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "global_find_one", dbid or GlobalDB.GLOBAL, tunpack(mongo_query))
end

--发送数据库请求
--{coll_name, selector, fields, sorts, limit}
function MongoAgent:global_find(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "global_find", dbid or GlobalDB.GLOBAL, tunpack(mongo_query))
end

--{coll_name, selector, single}
function MongoAgent:global_delete(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "global_delete", dbid or GlobalDB.GLOBAL, tunpack(mongo_query))
end

--{coll_name, obj, selector, upsert, multi}
function MongoAgent:global_update(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "global_update", dbid or GlobalDB.GLOBAL, tunpack(mongo_query))
end

--{coll_name, obj}
function MongoAgent:global_insert(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "global_insert", dbid or GlobalDB.GLOBAL, tunpack(mongo_query))
end

--{coll_name, selector}
function MongoAgent:global_count(hash_key, mongo_query, dbid)
    return router_mgr:call_dbsvr_hash(hash_key, "global_count", dbid or GlobalDB.GLOBAL, tunpack(mongo_query))
end

------------------------------------------------------------------
quanta.mongo_agent = MongoAgent()

return MongoAgent
