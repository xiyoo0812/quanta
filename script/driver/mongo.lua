local bson         = require "bson"
local driver       = require "mongo"
local socket       = require "msocket"
local pairs        = pairs
local rawget       = rawget
local assert       = assert
local tostring     = tostring
local setmetatable = setmetatable
local tinsert      = table.insert
local tunpack      = table.unpack
local mtointeger   = math.tointeger

local bson_encode = bson.encode
local bson_encode_order = bson.encode_order
local bson_decode = bson.decode
local empty_bson = bson_encode {}

local mongo = {}
mongo.null = bson.null
mongo.type = bson.type
mongo.maxkey = bson.maxkey
mongo.minkey = bson.minkey

local mongo_cursor = {}
local cursor_meta = {
    __index = mongo_cursor,
}

local mongo_client = {}

local client_meta = {
    __index = function(self, key)
        return rawget(mongo_client, key) or self:getDB(key)
    end,
    __tostring = function (self)
        local port_string
        if self.port then
            port_string = ":" .. tostring(self.port)
        else
            port_string = ""
        end

        return "[mongo client : " .. self.host .. port_string .."]"
    end,
    __gc = function(self)
        self:disconnect()
    end
}

local mongo_db = {}

local db_meta = {
    __index = function (self, key)
        return rawget(mongo_db, key) or self:getCollection(key)
    end,
    __tostring = function (self)
        return "[mongo db : " .. self.name .. "]"
    end
}

local mongo_collection = {}
local collection_meta = {
    __index = function(self, key)
        return rawget(mongo_collection, key) or self:getCollection(key)
    end,
    __tostring = function (self)
        return "[mongo collection : " .. self.full_name .. "]"
    end
}

function mongo.client(obj)
    obj.__id = 0
    obj.port = obj.port or 27017
    obj.__sock = assert(socket.open(obj.host, obj.port),"Connect failed")
    return setmetatable(obj, client_meta)
end

function mongo_client:getDB(dbname)
    local db = {
        connection = self,
        name = dbname,
        full_name = dbname,
        database = false,
        __cmd = dbname .. "." .. "$cmd",
    }

    db.database = db

    return setmetatable(db, db_meta)
end

function mongo_client:disconnect()
    if self.__sock then
        socket.close(self.__sock)
        self.__sock = nil
    end
end

function mongo_client:genId()
    local id = self.__id + 1
    self.__id = id
    return id
end

function mongo_client:runCommand(...)
    if not self.admin then
        self.admin = self:getDB "admin"
    end
    return self.admin:runCommand(...)
end

local function get_reply(sock, result)
    local len_err, data = socket.read(sock, 4)
    if 0 ~= len_err then
        return len_err
    end

    local length = driver.length(data)
    local data_err, reply = socket.read(sock, length)
    return data_err, reply, driver.reply(reply, result)
end

function mongo_db:runCommand(cmd,cmd_v,...)
    local request_id = self.connection:genId()
    local sock = self.connection.__sock
    local bson_cmd
    if not cmd_v then
        bson_cmd = bson_encode_order(cmd,1)
    else
        bson_cmd = bson_encode_order(cmd,cmd_v,...)
    end
    local pack = driver.query(request_id, 0, self.__cmd, 0, 1, bson_cmd)
    local write_err = socket.write(sock, pack)
    if 0 ~= write_err then
        return write_err
    end

    local read_err, _, _, reply_id, doc = get_reply(sock)
    if 0 ~= read_err then
        return read_err
    end
    assert(request_id == reply_id, "Reply from mongod error")
    return 0, bson_decode(doc)
end

function mongo_db:dropCollection(collection)
    local sock_err, ret = self:runCommand("drop", collection)

    return sock_err, ret
end

--[[
    indexes={
        {key={open_id=1,platform_id=1},name="open_id-platform_id",unique=true},
        {key={open_id=1},name="open_id",unique=false}
    }
]]
function mongo_db:buildIndexes(collection, indexes)
    local sock_err, ret = self:runCommand("createIndexes", collection, "indexes", indexes)

    return sock_err, ret
end

function mongo_db:getCollection(collection)
    local col = {
        connection = self.connection,
        name = collection,
        full_name = self.full_name .. "." .. collection,
        database = self.database,
    }
    self[collection] = setmetatable(col, collection_meta)
    return col
end

mongo_collection.getCollection = mongo_db.getCollection

local function werror(r)
    local ok = (r.ok == 1 and not r.writeErrors and not r.writeConcernError)

    local err
    if not ok then
        if r.writeErrors then
            err = r.writeErrors[1].errmsg
        else
            err = r.writeConcernError.errmsg
        end
    end
    return ok, err, r
end

function mongo_collection:insert(doc)
    if doc._id == nil then
        doc._id = bson.objectid()
    end
    local sock = self.connection.__sock
    local pack = driver.insert(0, self.full_name, bson_encode(doc))
    -- flags support 1: ContinueOnError
    local sock_err = socket.write(sock, pack)

    return sock_err
end

function mongo_collection:safe_insert(doc)
    local sock_err, r = self.database:runCommand("insert", self.name, "documents", {bson_encode(doc)})
    return sock_err, werror(r)
end

function mongo_collection:batch_insert(docs)
    for i=1,#docs do
        if docs[i]._id == nil then
            docs[i]._id = bson.objectid()
        end
        docs[i] = bson_encode(docs[i])
    end
    local sock = self.connection.__sock
    local pack = driver.insert(0, self.full_name, docs)
    local sock_err = socket.write(sock, pack)

    return sock_err
end

function mongo_collection:update(selector,update,upsert,multi)
    local flags = (upsert and 1 or 0) + (multi and 2 or 0)
    local sock = self.connection.__sock
    local pack = driver.update(self.full_name, flags, bson_encode(selector), bson_encode(update))
    local sock_err = socket.write(sock, pack)

    return sock_err
end

function mongo_collection:safe_update(selector, update, upsert, multi)
    local sock_err, r = self.database:runCommand("update", self.name, "updates", {bson_encode({
        q = selector,
        u = update,
        upsert = upsert,
        multi = multi,
    })})

    return sock_err, werror(r)
end

function mongo_collection:delete(selector, single)
    local sock = self.connection.__sock
    local pack = driver.delete(self.full_name, single, bson_encode(selector))

    local sock_err = socket.write(sock, pack)

    return sock_err
end

function mongo_collection:safe_delete(selector, single)
    local sock_err, r = self.database:runCommand("delete", self.name, "deletes", {bson_encode({
        q = selector,
        limit = single and 1 or 0,
    })})
    return sock_err, werror(r)
end

function mongo_collection:count(selector)
    if not selector then
        selector = {}
    end
    local sock_err, ret = self.database:runCommand("count", self.name, "query", selector)

    local ok = (1 == mtointeger(ret.ok))
    local n  = ok and mtointeger(ret.n) or nil  -- count

    return sock_err, {ok = ok, n = n}
end

function mongo_collection:findOne(query, selector)
    local request_id = self.connection:genId()
    local sock = self.connection.__sock
    local pack = driver.query(request_id, 0, self.full_name, 0, 1, query and bson_encode(query) or empty_bson, selector and bson_encode(selector))

    -- todo: check send
    local write_err = socket.write(sock, pack)
    if 0 ~= write_err then
        return write_err
    end
    local read_err, _, _, reply_id, doc = get_reply(sock)
    if 0 ~= read_err then
        return read_err
    end
    assert(request_id == reply_id, "Reply from mongod error")
    -- todo: check succ
    return 0, bson_decode(doc)
end

function mongo_collection:find(query, selector)
    return setmetatable( {
        __collection = self,
        __query = query and bson_encode(query) or empty_bson,
        __selector = selector and bson_encode(selector),
        __ptr = nil,
        __data = nil,
        __cursor = nil,
        __document = {},
        __flags = 0,
        __skip = 0,
        __sortquery = nil,
        __limit = 0,
    } , cursor_meta)
end

local function unfold(list, key, ...)
    if key == nil then
        return list
    end
    local next_func, t = pairs(key)
    local k, v = next_func(t)	-- The first key pair
    tinsert(list, k)
    tinsert(list, v)
    return unfold(list, ...)
end

-- cursor:sort { key = 1 } or cursor:sort( {key1 = 1}, {key2 = -1})
function mongo_cursor:sort(key, key_v, ...)
    if key_v then
        local key_list = unfold({}, key, key_v , ...)
        key = bson_encode_order(tunpack(key_list))
    end
    self.__sortquery = bson_encode {['$query'] = self.__query, ['$orderby'] = key}
    return self
end

function mongo_cursor:skip(amount)
    self.__skip = amount
    return self
end

function mongo_cursor:limit(amount)
    self.__limit = amount
    return self
end

function mongo_cursor:count(with_limit_and_skip)
    local cmd = {
        'count', self.__collection.name,
        'query', self.__query,
    }
    if with_limit_and_skip then
        local len = #cmd
        cmd[len+1] = 'limit'
        cmd[len+2] = self.__limit
        cmd[len+3] = 'skip'
        cmd[len+4] = self.__skip
    end
    local sock_err, ret = self.__collection.database:runCommand(tunpack(cmd))
    if 0 ~= sock_err then
        return sock_err
    end
    assert(ret and ret.ok == 1)
    return sock_err, ret.n
end

function mongo_cursor:hasNext()
    local sock_err = 0
    if self.__ptr == nil then
        if self.__document == nil then
            return 0, false
        end
        local conn = self.__collection.connection
        local request_id = conn:genId()
        local sock = conn.__sock
        local pack
        if self.__data == nil then
            pack = driver.query(request_id, self.__flags, self.__collection.full_name,0,0,self.__query,self.__selector)
        else
            if self.__cursor then
                pack = driver.more(request_id, self.__collection.full_name,0,self.__cursor)
            else
                -- no more
                self.__document = nil
                self.__data = nil
                return 0, false
            end
        end

        sock_err = socket.write(sock, pack)
        if 0 ~= sock_err then
            return sock_err, false
        end

        local data, succ, reply_id, doc, cursor
        sock_err, data, succ, reply_id, doc, cursor = get_reply(sock, self.__document)
        if 0 ~= sock_err then
            return sock_err, false
        end
        assert(request_id == reply_id, "Reply from mongod error")
        if succ then
            if doc then
                self.__data = data
                self.__ptr = 1
                self.__cursor = cursor
                return 0, true
            else
                self.__document = nil
                self.__data = nil
                self.__cursor = nil
                return 0, false
            end
        else
            self.__document = nil
            self.__data = nil
            self.__cursor = nil
            if doc then
                local err = bson_decode(doc)
                error(err["$err"])
            else
                error("Reply from mongod error")
            end
        end
    end

    return sock_err, true
end

function mongo_cursor:next()
    if self.__ptr == nil then
        error "Call hasNext first"
    end
    local r = bson_decode(self.__document[self.__ptr])
    self.__ptr = self.__ptr + 1
    if self.__ptr > #self.__document then
        self.__ptr = nil
    end

    return r
end

function mongo_cursor:close()
    -- todo: warning hasNext after close
    local sock_err = 0
    if self.__cursor then
        local sock = self.__collection.connection.__sock
        local pack = driver.kill(self.__cursor)
        sock_err   = socket.write(sock, pack)
        if 0 ~= sock_err then
            return sock_err
        end
    end

    return sock_err
end

return mongo
