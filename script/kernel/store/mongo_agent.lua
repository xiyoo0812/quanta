--mongo_agent.lua
local tunpack           = table.unpack
local env_number        = environ.number

local router_mgr        = quanta.get("router_mgr")

local DBGroup           = enum("DBGroup")
local DBGROUP_AREA      = DBGroup.AREA

local MongoAgent = singleton()
function MongoAgent:__init()
    self.area_id = env_number("QUANTA_AREA_ID")
end

--db_query: {coll_name, selector, fields}
function MongoAgent:find_one(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_find_one", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

--db_query: {coll_name, selector, fields, sortor, limit}
function MongoAgent:find(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_find", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

--db_query: {coll_name, selector, fields, sortor, limit}
function MongoAgent:collect(hash_key, db_query, db_group)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_collect", db_group or DBGROUP_AREA, tunpack(db_query))
end

--db_query: {coll_name, selector, single}
function MongoAgent:delete(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_delete", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

--db_query: {coll_name, obj, selector, upsert, multi}
function MongoAgent:update(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_update", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

--db_query: {coll_name, obj}
function MongoAgent:insert(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_insert", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

--db_query: {coll_name, selector}
function MongoAgent:count(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_count", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

--db_query: {coll_name, indexes}
function MongoAgent:create_indexes(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_create_indexes", db_group or DBGROUP_AREA, db_area or 0, tunpack(db_query))
end

--db_query: {coll_name, index_name}
function MongoAgent:drop_indexes(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_drop_indexes", db_group or DBGROUP_AREA, db_area or 0, tunpack(db_query))
end

--db_query: {cmd, ...}
function MongoAgent:execute(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "mongo_execute", db_group or DBGROUP_AREA, db_area or 0, tunpack(db_query))
end
------------------------------------------------------------------
quanta.mongo_agent = MongoAgent()

return MongoAgent
