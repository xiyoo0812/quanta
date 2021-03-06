
--mongo.lua
import("driver/poll.lua")
local bson          = require "bson"
local driver        = require "mongo"
local Socket        = import("driver/socket.lua")

local ipairs        = ipairs
local tinsert       = table.insert
local tunpack       = table.unpack
local mtointeger    = math.tointeger

local log_info      = logger.info
local bson_encode   = bson.encode
local bson_decode   = bson.decode
local bson_encode_order = bson.encode_order
local empty_bson    = bson_encode {}

local NetwkTime     = enum("NetwkTime")
local PeriodTime    = enum("PeriodTime")

local poll          = quanta.get("poll")
local timer_mgr     = quanta.get("timer_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local MongoDB = class()
local prop = property(MongoDB)
prop:accessor("ip", nil)            --mongo地址
prop:accessor("sock", nil)          --网络连接对象
prop:accessor("name", "")           --dbname
prop:accessor("db_cmd", "")         --默认cmd
prop:accessor("port", 27017)        --mongo端口

function MongoDB:__init(db_name, ip, port)
    self.ip = ip
    self.port = port
    self.name = db_name
    self.db_cmd = db_name .. "." .. "$cmd"
    --update
    timer_mgr:loop(PeriodTime.SECOND_MS, function()
        self:upadte()
    end)
end

function MongoDB:__release()
    self:close()
end

function MongoDB:close()
    if self.sock then
        self.sock:close()
        self.sock = nil
    end
end

function MongoDB:upadte()
    if not self.sock then
        local sock = Socket(poll, self)
        if sock:connect(self.ip, self.port) then
            log_info("[MongoDB][upadte] connect db(%s:%s) success!", self.ip, self.port)
            self.sock = sock
        end
    end
end

function MongoDB:on_socket_close()
    self.sock = nil
end

function MongoDB:on_socket_recv(sock)
    while true do
        local hdata = sock:peek(4)
        if not hdata then
            break
        end
        local length = driver.length(hdata)
        local bdata = sock:peek(length, 4)
        if not bdata then
            break
        end
        sock:pop(4 + length)
        local documents = {}
        local succ, session_id, doc, cursor_id = driver.reply(bdata, documents)
        thread_mgr:response(session_id, succ, doc, cursor_id, documents)
    end
end

function MongoDB:mongo_result(succ, doc)
    if type(doc) == "string" then
        return succ, doc
    end
    if type(doc) == "userdata" then
        doc = bson_decode(doc) or {}
    end
    if doc.writeErrors then
        return false, doc.writeErrors[1].errmsg
    end
    if doc.writeConcernError then
        return false, doc.writeConcernError.errmsg
    end
    if succ and doc.ok == 1 then
        return true, doc
    end
    return false, doc.errmsg or doc["$err"]
end

function MongoDB:_query(full_name, query, selector, query_num, skip, flag)
    if not self.sock then
        return false, "db not connected"
    end
    local bson_query = query or empty_bson
    local bson_selector = selector or empty_bson
    local session_id = thread_mgr:build_session_id()
    local pack = driver.query(session_id, flag or 0, full_name, skip or 0, query_num or 1, bson_query, bson_selector)
    if not self.sock:send(pack) then
        return false, "send failed"
    end
    return thread_mgr:yield(session_id, "mongo_query", NetwkTime.MONGO_CALL_TIMEOUT)
end


function MongoDB:_more(full_name, cursor, query_num)
    if not self.sock then
        return false, "db not connected"
    end
    local session_id = thread_mgr:build_session_id()
    local pack = driver.more(session_id, full_name, query_num or 0, cursor)
    if not self.sock:send(pack) then
        return false, "send failed"
    end
    local succ, doc, new_cursor, documents = thread_mgr:yield(session_id, "mongo_more", NetwkTime.MONGO_CALL_TIMEOUT)
    if not succ then
        return self:mongo_result(succ, doc)
    end
    return true, new_cursor, documents
end

function MongoDB:runCommand(cmd, cmd_v, ...)
    local bson_cmd
    if not cmd_v then
        bson_cmd = bson_encode_order(cmd, 1)
    else
        bson_cmd = bson_encode_order(cmd, cmd_v, ...)
    end
    local succ, doc = self:_query(self.db_cmd, bson_cmd)
    return self:mongo_result(succ, doc)
end

function MongoDB:drop_collection(collection)
    return self:runCommand("drop", collection)
end

-- 参数说明
-- indexes={{key={open_id=1,platform_id=1},name="open_id-platform_id",unique=true}, }
function MongoDB:build_indexes(collection, indexes)
    return self:runCommand("createIndexes", collection, "indexes", indexes)
end

function MongoDB:insert(collection, doc)
    return self:runCommand("insert", collection, "documents", {bson_encode(doc)})
end

function MongoDB:update(collection, update, selector, upsert, multi)
    local bson_data = bson_encode({ q = selector, u = update, upsert = upsert, multi = multi })
    return self:runCommand("update", collection, "updates", {bson_data})
end

function MongoDB:delete(collection, selector, onlyone)
    local bson_data = bson_encode({ q = selector, limit = onlyone and 1 or 0 })
    return self:runCommand("delete", collection, "deletes", {bson_data})
end

function MongoDB:count(collection, selector, limit, skip)
    local cmds = {}
    if limit then
        tinsert(cmds, "limit")
        tinsert(cmds, limit)
    end
    if skip then
        tinsert(cmds, "skip")
        tinsert(cmds, skip)
    end
    local succ, doc = self:runCommand("count", collection, "query", selector, tunpack(cmds))
    if not succ then
        return succ, doc
    end
    return succ, mtointeger(doc.n)
end

function MongoDB:find_one(collection, selector, fields)
    local full_name = self.name .. "." .. collection
    local bson_selector = selector and bson_encode(selector)
    local bson_fields = fields and bson_encode(fields)
    local succ, doc = self:_query(full_name, bson_selector, bson_fields)
    if succ then
        return succ, bson_decode(doc)
    end
    return succ, doc
end

function MongoDB:build_results(documents, results, limit)
    for i, _doc in ipairs(documents) do
        if limit and #results >= limit then
            break
        end
        tinsert(results, bson_decode(_doc))
    end
end

function MongoDB:find(collection, selector, fields, limit, query_num)
    local query_num_once = query_num or limit or 100
    local full_name = self.name .. "." .. collection
    local bson_selector = selector and bson_encode(selector)
    local bson_fields = fields and bson_encode(fields)
    local succ, doc, cursor, documents = self:_query(full_name, bson_selector, bson_fields, query_num_once)
    if not succ then
        return self:mongo_result(succ, doc)
    end
    local results = {}
    self:build_results(documents, results, limit)
    while cursor do
        if limit and #results >= limit then
            break
        end
        local _succ, _cursor_oe, _documents = self:_more(full_name, cursor, query_num_once)
        if not _succ then
            return _succ, _cursor_oe
        end
        self:build_results(_documents, results, limit)
        cursor = _cursor_oe
    end
    return true, results
end

return MongoDB
