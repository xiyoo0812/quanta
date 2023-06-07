
--mongo.lua
local lbus          = require("luabus")
local lmongo        = require("lmongo")
local ltimer        = require("ltimer")
local lcrypt        = require("lcrypt")
local Socket        = import("driver/socket.lua")

local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn
local qjoin         = qtable.join
local qhash         = quanta.hash
local tunpack       = table.unpack
local ssub          = string.sub
local sgsub         = string.gsub
local sformat       = string.format
local sgmatch       = string.gmatch
local mtointeger    = math.tointeger
local lmd5          = lcrypt.md5
local lsha1         = lcrypt.sha1
local lrandomkey    = lcrypt.randomkey
local lb64encode    = lcrypt.b64_encode
local lb64decode    = lcrypt.b64_decode
local lhmac_sha1    = lcrypt.hmac_sha1
local lxor_byte     = lcrypt.xor_byte
local lclock_ms     = ltimer.clock_ms
local mreply        = lmongo.reply_slice
local mopmsg        = lmongo.opmsg_slice
local mdecode       = lmongo.decode_slice
local mencode_s     = lmongo.encode_sparse
local mencode_o     = lmongo.encode_order_slice

local eproto_type   = lbus.eproto_type

local timer_mgr     = quanta.get("timer_mgr")
local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local update_mgr    = quanta.get("update_mgr")

local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")
local DB_TIMEOUT    = quanta.enum("NetwkTime", "DB_CALL_TIMEOUT")
local POOL_COUNT    = environ.number("QUANTA_DB_POOL_COUNT", 9)

local MongoDB = class()
local prop = property(MongoDB)
prop:reader("id", nil)          --id
prop:reader("name", "")         --dbname
prop:reader("user", nil)        --user
prop:reader("passwd", nil)      --passwd
prop:reader("executer", nil)    --执行者
prop:reader("timer_id", nil)    --timer_id
prop:reader("cursor_id", nil)   --cursor_id
prop:reader("connections", {})  --connections
prop:reader("readpref", nil)    --readPreference
prop:reader("req_counter", nil)
prop:reader("res_counter", nil)

function MongoDB:__init(conf, id)
    self.id = id
    self.name = conf.db
    self.user = conf.user
    self.passwd = conf.passwd
    self.cursor_id = lmongo.int64(0)
    self:choose_host(conf.hosts)
    self:set_options(conf.opts)
    --attach_hour
    update_mgr:attach_hour(self)
    --counter
    self.req_counter = quanta.make_sampling(sformat("mongo %s req", self.id))
    self.res_counter = quanta.make_sampling(sformat("mongo %s res", self.id))
end

function MongoDB:close()
    for sock in pairs(self.connections) do
        sock:close()
    end
end

function MongoDB:set_executer(id)
    local index = qhash(id, POOL_COUNT)
    self.executer = self.connections[index]
end

function MongoDB:set_options(opts)
    for key, value in pairs(opts) do
        if key == "readPreference" then
            self.readpref = { mode = value }
        end
    end
end

function MongoDB:choose_host(hosts)
    if not next(hosts) then
        log_err("[MongoDB][choose_host] mongo config err: hosts is empty")
        return
    end
    local count = POOL_COUNT
    while count > 0 do
        for ip, port in pairs(hosts) do
            local socket = Socket(self, ip, port)
            socket.sessions = {}
            self.connections[count] = socket
            count = count - 1
        end
    end
    self.timer_id = timer_mgr:loop(SECOND_MS, function()
        self:check_alive()
    end)
end

function MongoDB:check_alive()
    local ok = true
    for no, sock in pairs(self.connections) do
        if not sock:is_alive() then
            if not self:login(sock, no) then
                ok = false
            end
        end
    end
    timer_mgr:set_period(self.timer_id, ok and SECOND_10_MS or SECOND_MS)
end

function MongoDB:on_hour()
    for _, sock in pairs(self.connections) do
        if not sock:is_alive() then
            self.executer = sock
            self:runCommand("ping")
        end
    end
end

function MongoDB:login(socket, no)
    local ip, port = socket.ip, socket.port
    local ok, err = socket:connect(ip, port, eproto_type.common)
    if not ok then
        log_err("[MongoDB][on_second] connect db(%s:%s:%s:%s) failed: %s!", ip, port, self.name, no, err)
        return
    end
    self.executer = socket
    if self.user and self.passwd then
        local aok, aerr = self:auth(self.user, self.passwd)
        if not aok then
            socket:close()
            log_err("[MongoDB][on_second] auth db(%s:%s:%s:%s) failed! because: %s", ip, port, self.name, no, aerr)
            return
        end
    end
    log_info("[MongoDB][on_second] connect db(%s:%s:%s:%s) success!", ip, port,self.name, no)
end

local function salt_password(password, salt, iter)
    salt = salt .. "\0\0\0\1"
    local output = lhmac_sha1(password, salt)
    local inter = output
    for i = 2, iter do
        inter = lhmac_sha1(password, inter)
        output = lxor_byte(output, inter)
    end
    return output
end

function MongoDB:auth(username, password)
    local nonce = lb64encode(lrandomkey())
    local user = sgsub(sgsub(username, '=', '=3D'), ',', '=2C')
    local first_bare = "n="  .. user .. ",r="  .. nonce
    local sasl_start_payload = lb64encode("n,," .. first_bare)
    local sok, sdoc = self:adminCommand("saslStart", 1, "autoAuthorize", 1, "mechanism", "SCRAM-SHA-1", "payload", sasl_start_payload)
    if not sok then
        return sok, sdoc
    end

    local conversationId = sdoc['conversationId']
    local str_payload_start = lb64decode(sdoc['payload'])
    local payload_start = {}
    for k, v in sgmatch(str_payload_start, "(%w+)=([^,]*)") do
        payload_start[k] = v
    end
    local salt = payload_start['s']
    local rnonce = payload_start['r']
    local iterations = tonumber(payload_start['i'])
    if not ssub(rnonce, 1, 12) == nonce then
        return false, "Server returned an invalid nonce."
    end
    local without_proof = "c=biws,r=" .. rnonce
    local pbkdf2_key = lmd5(sformat("%s:mongo:%s", username, password), 1)
    local salted_pass = salt_password(pbkdf2_key, lb64decode(salt), iterations)
    local client_key = lhmac_sha1(salted_pass, "Client Key")
    local stored_key = lsha1(client_key)
    local auth_msg = first_bare .. ',' .. str_payload_start .. ',' .. without_proof
    local client_sig = lhmac_sha1(stored_key, auth_msg)
    local client_key_xor_sig = lxor_byte(client_key, client_sig)
    local client_proof = "p=" .. lb64encode(client_key_xor_sig)
    local client_final = lb64encode(without_proof .. ',' .. client_proof)

    local cok, cdoc = self:adminCommand("saslContinue", 1, "conversationId", conversationId, "payload", client_final)
    if not cok then
        return cok, cdoc
    end
    local payload_continue = {}
    local str_payload_continue = lb64decode(cdoc['payload'])
    for k, v in sgmatch(str_payload_continue, "(%w+)=([^,]*)") do
        payload_continue[k] = v
    end
    local server_key = lhmac_sha1(salted_pass, "Server Key")
    local server_sig = lb64encode(lhmac_sha1(server_key, auth_msg))
    if payload_continue['v'] ~= server_sig then
        log_err("Server returned an invalid signature.")
        return false
    end
    if not cdoc.done then
        local ccok, ccdoc = self:adminCommand("saslContinue", 1, "conversationId", conversationId, "payload", "")
        if not ccok or not ccdoc.done then
            return false, "SASL conversation failed to complete."
        end
    end
    return true
end

function MongoDB:on_socket_error(sock, token, err)
    for session_id in pairs(sock.sessions) do
        thread_mgr:response(session_id, false, err)
    end
    sock.sessions = {}
    event_mgr:fire_next_second(function()
        self:check_alive()
    end)
end

function MongoDB:decode_reply(succ, slice)
    local doc = mdecode(slice)
    if doc.writeErrors then
        return false, doc.writeErrors[1].errmsg
    end
    if doc.writeConcernError then
        return false, doc.writeConcernError.errmsg
    end
    if succ and doc.ok == 1 then
        return succ, doc
    end
    return false, doc.errmsg or doc["$err"]
end

function MongoDB:on_slice_recv(sock, slice, token)
    local sessions = sock.sessions
    local ok, session_id = mreply(slice)
    local time, cmd = tunpack(sessions[session_id])
    local utime = lclock_ms() - time
    if utime > 100 then
        log_warn("[MongoDB][on_slice_recv] cmd (%s:%s) execute so big %s!", cmd, session_id, utime)
    end
    sessions[session_id] = nil
    self.res_counter:count_increase()
    local succ, doc = self:decode_reply(ok, slice)
    thread_mgr:response(session_id, succ, doc)
end

function MongoDB:op_msg(slice_bson, cmd)
    local sock = self.executer
    if not sock then
        return false, "db not connected"
    end
    local session_id = thread_mgr:build_session_id()
    local slice = mopmsg(slice_bson, session_id, 0)
    if not sock:send_slice(slice) then
        return false, "send failed"
    end
    self.req_counter:count_increase()
    sock.sessions[session_id] = { lclock_ms(), cmd }
    return thread_mgr:yield(session_id, "mongo_op_msg", DB_TIMEOUT)
end

function MongoDB:adminCommand(cmd, cmd_v, ...)
    local slice_bson = mencode_o(cmd, cmd_v, "$db", "admin", ...)
    return self:op_msg(slice_bson, cmd)
end

function MongoDB:runCommand(cmd, cmd_v, ...)
    local slice_bson = mencode_o(cmd, cmd_v or 1, "$db", self.name, ...)
    return self:op_msg(slice_bson, cmd)
end

function MongoDB:sendCommand(cmd, cmd_v, ...)
    if not self.executer then
        return false, "db not connected"
    end
    local slice_bson = mencode_o(cmd, cmd_v or 1, "$db", self.name, "writeConcern", {w=0}, ...)
    local pack = mopmsg(slice_bson, 0, 0)
    self.executer:send(pack)
    return true
end

function MongoDB:drop_collection(co_name)
    return self:runCommand("drop", co_name)
end

-- 参数说明
-- indexes={{key={open_id=1,platform_id=1},name="open_id-platform_id",unique=true}, }
function MongoDB:create_indexes(co_name, indexes)
    local succ, doc = self:runCommand("createIndexes", co_name, "indexes", indexes)
    if not succ then
        return succ, doc
    end
    return succ
end

function MongoDB:drop_indexes(co_name, index_name)
    local succ, doc = self:runCommand("dropIndexes", co_name, "index", index_name)
    if not succ then
        return succ, doc
    end
    return succ
end

function MongoDB:insert(co_name, doc)
    return self:runCommand("insert", co_name, "documents", { mencode_s(doc) })
end

function MongoDB:update(co_name, update, selector, upsert, multi)
    local cmd_data = { q = selector, u = mencode_s(update), upsert = upsert, multi = multi }
    return self:runCommand("update", co_name, "updates", { cmd_data })
end

function MongoDB:delete(co_name, selector, onlyone)
    local cmd_data = { q = selector, limit = onlyone and 1 or 0 }
    return self:runCommand("delete", co_name, "deletes", { cmd_data })
end

function MongoDB:count(co_name, query, limit, skip)
    local succ, doc = self:runCommand("count", co_name, "query", query, "limit", limit, "skip", skip)
    if not succ then
        return succ, doc
    end
    return succ, mtointeger(doc.n)
end

function MongoDB:find_one(co_name, query, projection)
    local succ, reply = self:runCommand("find", co_name, "$readPreference", self.readpref, "filter", query, "projection", projection, "limit", 1)
    if not succ then
        return succ, reply
    end
    local documents = reply.cursor.firstBatch
    if #documents > 0 then
        return succ, documents[1]
    end
    return succ
end

function MongoDB:find(co_name, query, projection, sortor, limit, skip)
    local succ, reply = self:runCommand("find", co_name, "$readPreference", self.readpref, "filter",
                query, "projection", projection, "sort", sortor, "limit", limit, "skip", skip)
    if not succ then
        return succ, reply
    end
    local results = {}
    local cursor = reply.cursor
    while cursor do
        local documents = cursor.firstBatch or cursor.nextBatch
        qjoin(documents, results)
        if not cursor.id or cursor.id == 0 then
            break
        end
        if limit and #results >= limit then
            break
        end
        self.cursor_id.val = cursor.id
        local msucc, moreply = self:runCommand("getMore", self.cursor_id, "collection", co_name, "batchSize", limit)
        if not msucc then
            return msucc, moreply
        end
        cursor = moreply.cursor
    end
    return true, results
end

function MongoDB:find_and_modify(co_name, update, selector, upsert, fields, new)
    return self:runCommand("findAndModify", co_name, "query", selector, "update", update, "fields", fields, "upsert", upsert, "new", new)
end

return MongoDB
