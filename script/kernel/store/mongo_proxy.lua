--mongo_proxy.lua
local tunpack       = table.unpack
local sname2sid     = service.name2sid

local router_mgr    = quanta.router_mgr

local MongoProxy = singleton()
function MongoProxy:__init()
    self.service_id = sname2sid("dbsvr")
end

--发送数据库请求
--{coll_name, selector, fields}
function MongoProxy:find_one(hash_key, mongo_query, dbid)
    return router_mgr:call_hash(self.service_id, hash_key, "mongo_find_one", dbid or 1, tunpack(mongo_query))
end

--发送数据库请求
--{coll_name, selector, fields, sorts, limit}
function MongoProxy:find(hash_key, mongo_query, dbid)
    return router_mgr:call_hash(self.service_id, hash_key, "mongo_find", dbid or 1, tunpack(mongo_query))
end

--{coll_name, selector, single}
function MongoProxy:delete(hash_key, mongo_query, dbid)
    return router_mgr:call_hash(self.service_id, hash_key, "mongo_delete", dbid or 1, tunpack(mongo_query))
end

--{coll_name, obj, selector, upsert, multi}
function MongoProxy:update(hash_key, mongo_query, dbid)
    return router_mgr:call_hash(self.service_id, hash_key, "mongo_update", dbid or 1, tunpack(mongo_query))
end

--{coll_name, obj}
function MongoProxy:insert(hash_key, mongo_query, dbid)
    return router_mgr:call_hash(self.service_id, hash_key, "mongo_insert", dbid or 1, tunpack(mongo_query))
end

------------------------------------------------------------------
quanta.mongo_proxy = MongoProxy()

return MongoProxy
