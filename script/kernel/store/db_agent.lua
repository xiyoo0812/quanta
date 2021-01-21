--db_agent.lua
local tunpack           = table.unpack
local env_number        = environ.number

local router_mgr        = quanta.get("router_mgr")

local DBGroup           = enum("DBGroup")
local DBGROUP_AREA      = DBGroup.AREA

local DBAgent = singleton()
function DBAgent:__init()
    self.area_id = env_number("QUANTA_AREA_ID")
end

--发送数据库请求
--{coll_name, selector, fields}
function DBAgent:find_one(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "find_one", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

--发送数据库请求
--{coll_name, selector, fields, limit}
function DBAgent:find(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "find", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

--发送数据库请求
--{coll_name, selector, fields, limit}
function DBAgent:collect(hash_key, db_query, db_group)
    return router_mgr:call_dbsvr_hash(hash_key, "collect", db_group or DBGROUP_AREA, tunpack(db_query))
end

--{coll_name, selector, single}
function DBAgent:delete(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "delete", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

--{coll_name, obj, selector, upsert, multi}
function DBAgent:update(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "update", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

--{coll_name, obj}
function DBAgent:insert(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "insert", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

--{coll_name, selector}
function DBAgent:count(hash_key, db_query, db_group, db_area)
    return router_mgr:call_dbsvr_hash(hash_key, "count", db_group or DBGROUP_AREA, db_area or self.area_id, tunpack(db_query))
end

------------------------------------------------------------------
quanta.db_agent = DBAgent()

return DBAgent
