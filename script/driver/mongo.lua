
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

local timer_mgr     = quanta.timer_mgr
local thread_mgr    = quanta.thread_mgr

local MongoDB = class()
local prop = property(MongoDB)
prop:accessor("ip", nil)            --mongo地址
prop:accessor("sock", nil)          --网络连接对象
prop:accessor("name", "")           --dbname
prop:accessor("db_cmd", "")         --默认cmd
prop:accessor("port", 27017)        --mongo端口
prop:accessor("documents", nil)     --find的文档列表

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
        local sock = Socket(quanta.poll, self)
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
    local hdata = sock:peek(4)
    if hdata then
        local length = driver.length(hdata)
        local bdata = sock:peek(length, 4)
        if bdata then
            sock:pop(4 + length)
            local succ, session_id, doc, cursor_id, startfrom = driver.reply(bdata, self.documents)
            thread_mgr:response(session_id, succ, doc, cursor_id, startfrom)
        end
    end
end

function MongoDB:mongo_result(succ, doc)
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
        return false, { errmsg = "db not connected" }
    end
    local bson_query = query or empty_bson
    local bson_selector = selector or empty_bson
    local session_id = thread_mgr:build_session_id()
    local pack = driver.query(session_id, flag or 0, full_name, skip or 0, query_num or 1, bson_query, bson_selector)
    if not self.sock:send(pack) then
        return false, { errmsg = "send failed" }
    end
    return thread_mgr:yield(session_id, NetwkTime.MONGO_CALL_TIMEOUT)
end


function MongoDB:_more(full_name, cursor, query_num)
    if not self.sock then
        return false, { errmsg = "db not connected" }
    end
    local session_id = thread_mgr:build_session_id()
    local pack = driver.more(session_id, full_name, query_num or 0, cursor)
    if not self.sock:send(pack) then
        return false, { errmsg = "send failed" }
    end
    local succ, doc, new_cursor = thread_mgr:yield(session_id, NetwkTime.MONGO_CALL_TIMEOUT)
    if not succ then
        return self:mongo_result(succ, doc)
    end
    return true, new_cursor
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

function MongoDB:find_one(collection, query, selector)
    local full_name = self.name .. "." .. collection
    local bson_query = query and bson_encode(query)
    local bson_selector = selector and bson_encode(selector)
    local succ, doc = self:_query(full_name, bson_query, bson_selector)
    return succ, bson_decode(doc)
end

function MongoDB:find(collection, query, selector, limit, query_num)
    self.documents = {}
    local real_limit = limit or 0
    local real_query_num = query_num or real_limit
    local full_name = self.name .. "." .. collection
    local bson_query = query and bson_encode(query)
    local bson_selector = selector and bson_encode(selector)
    local succ, doc, cursor = self:_query(full_name, bson_query, bson_selector, real_query_num)
    if not succ then
        return self:mongo_result(succ, doc)
    end
    local results = {}
    for _, _doc in ipairs(self.documents) do
        tinsert(results, bson_decode(_doc))
    end
    while cursor and #results < real_limit do
        local _succ, _cursor_oe = self:_more(full_name, cursor, real_query_num)
        if not _succ then
            return _succ, _cursor_oe
        end
        for _, _doc in ipairs(self.documents) do
            tinsert(results, bson_decode(_doc))
        end
        cursor = _cursor_oe
    end
    self.documents = nil
    return true, results
end

return MongoDB
