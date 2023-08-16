
--mongo.lua
local Socket        = import("driver/socket.lua")

local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn
local tinsert       = table.insert
local qjoin         = qtable.join
local tdelete       = qtable.delete
local ssub          = string.sub
local sgsub         = string.gsub
local spack         = string.pack
local sformat       = string.format
local sgmatch       = string.gmatch
local sunpack       = string.unpack
local mrandom       = qmath.random
local mtointeger    = math.tointeger
local qhash         = codec.hash_code
local qdefer        = quanta.defer
local makechan      = quanta.make_channel

local lmd5          = crypt.md5
local lsha1         = crypt.sha1
local mdecode       = bson.decode
local mencode_o     = bson.encode_order
local lrandomkey    = crypt.randomkey
local lb64encode    = crypt.b64_encode
local lb64decode    = crypt.b64_decode
local lhmac_sha1    = crypt.hmac_sha1
local lxor_byte     = crypt.xor_byte
local lclock_ms     = timer.clock_ms

local eproto_type   = luabus.eproto_type

local timer_mgr     = quanta.get("timer_mgr")
local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local update_mgr    = quanta.get("update_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local FAST_MS       = quanta.enum("PeriodTime", "FAST_MS")
local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")
local DB_TIMEOUT    = quanta.enum("NetwkTime", "DB_CALL_TIMEOUT")
local POOL_COUNT    = environ.number("QUANTA_DB_POOL_COUNT", 9)

local OP_MSG_CODE   = 2013;
local OP_MSG_HLEN   = 4 * 5 + 1
local OP_CHECKSUM   = 1 << 0;
local OP_MORE_COME  = 1 << 1;

local MongoDB = class()
local prop = property(MongoDB)
prop:reader("id", nil)          --id
prop:reader("name", "")         --dbname
prop:reader("user", nil)        --user
prop:reader("passwd", nil)      --passwd
prop:reader("salted_pass", nil) --salted_pass
prop:reader("executer", nil)    --执行者
prop:reader("timer_id", nil)    --timer_id
prop:reader("cursor_id", nil)   --cursor_id
prop:reader("connections", {})  --connections
prop:reader("readpref", nil)    --readPreference
prop:reader("alives", {})       --alives
prop:reader("req_counter", nil)
prop:reader("res_counter", nil)

function MongoDB:__init(conf, id)
    self.id = id
    self.name = conf.db
    self.user = conf.user
    self.passwd = conf.passwd
    self.cursor_id = bson.int64(0)
    self:set_options(conf.opts)
    self:setup_pool(conf.hosts)
    --attach_hour
    update_mgr:attach_hour(self)
    --counter
    self.req_counter = quanta.make_sampling(sformat("mongo %s req", self.id))
    self.res_counter = quanta.make_sampling(sformat("mongo %s res", self.id))
end

function MongoDB:__release()
    self:close()
end

function MongoDB:close()
    for sock in pairs(self.alives) do
        sock:close()
    end
    for sock in pairs(self.connections) do
        sock:close()
    end
    self.connections = {}
    self.alives = {}
end

function MongoDB:set_options(opts)
    for key, value in pairs(opts) do
        if key == "readPreference" then
            self.readpref = { mode = value }
        end
    end
end

function MongoDB:setup_pool(hosts)
    if not next(hosts) then
        log_err("[MongoDB][setup_pool] mongo config err: hosts is empty")
        return
    end
    local count = POOL_COUNT
    while count > 0 do
        for ip, port in pairs(hosts) do
            local socket = Socket(self, ip, port)
            self.connections[count] = socket
            socket.sessions = {}
            socket:set_id(count)
            count = count - 1
        end
    end
    self.timer_id = timer_mgr:register(0, SECOND_MS, -1, function()
        self:check_alive()
    end)
end

function MongoDB:set_executer(id)
    local count = #self.alives
    if count > 0 then
        local index = qhash(id or mrandom(), count)
        self.executer = self.alives[index]
        return true
    end
    return false
end

function MongoDB:available()
    return #self.alives > 0
end

function MongoDB:check_alive()
    if next(self.connections) then
        thread_mgr:entry(self:address(), function()
            local channel = makechan("check mongo")
            for _, sock in pairs(self.connections) do
                channel:push(function()
                    return self:login(sock)
                end)
            end
            if channel:execute(true) then
                timer_mgr:set_period(self.timer_id, SECOND_10_MS)
            end
            self:set_executer()
        end)
    end
end

function MongoDB:on_hour()
    for _, sock in pairs(self.alives) do
        self.executer = sock
        self:sendCommand("ping")
    end
end

function MongoDB:login(socket)
    local id, ip, port = socket.id, socket.ip, socket.port
    local ok, err = socket:connect(ip, port, eproto_type.common)
    if not ok then
        log_err("[MongoDB][login] connect db(%s:%s:%s:%s) failed: %s!", ip, port, self.name, id, err)
        return false
    end
    if self.user and self.passwd then
        local aok, aerr = self:auth(socket, self.user, self.passwd)
        if not aok then
            log_err("[MongoDB][login] auth db(%s:%s:%s:%s) failed! because: %s", ip, port, self.name, id, aerr)
            self:delive(socket)
            socket:close()
            return false
        end
    end
    self.connections[id] = nil
    tinsert(self.alives, socket)
    log_info("[MongoDB][login] connect db(%s:%s:%s:%s) success!", ip, port,self.name, id)
    return true, SUCCESS
end

function MongoDB:salt_password(password, salt, iter)
    if self.salted_pass then
        return self.salted_pass
    end
    salt = salt .. "\0\0\0\1"
    local output = lhmac_sha1(password, salt)
    local inter = output
    for i = 2, iter do
        inter = lhmac_sha1(password, inter)
        output = lxor_byte(output, inter)
    end
    self.salted_pass = output
    return output
end

function MongoDB:auth(sock, username, password)
    local nonce = lb64encode(lrandomkey())
    local user = sgsub(sgsub(username, '=', '=3D'), ',', '=2C')
    local first_bare = "n="  .. user .. ",r="  .. nonce
    local sasl_start_payload = lb64encode("n,," .. first_bare)
    local sok, sdoc = self:adminCommand(sock, "saslStart", 1, "autoAuthorize", 1, "mechanism", "SCRAM-SHA-1", "payload", sasl_start_payload)
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
    local salted_pass = self:salt_password(pbkdf2_key, lb64decode(salt), iterations)
    local client_key = lhmac_sha1(salted_pass, "Client Key")
    local stored_key = lsha1(client_key)
    local auth_msg = first_bare .. ',' .. str_payload_start .. ',' .. without_proof
    local client_sig = lhmac_sha1(stored_key, auth_msg)
    local client_key_xor_sig = lxor_byte(client_key, client_sig)
    local client_proof = "p=" .. lb64encode(client_key_xor_sig)
    local client_final = lb64encode(without_proof .. ',' .. client_proof)

    local cok, cdoc = self:adminCommand(sock, "saslContinue", 1, "conversationId", conversationId, "payload", client_final)
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
        return false, "Server returned an invalid signature."
    end
    if not cdoc.done then
        local ccok, ccdoc = self:adminCommand(sock, "saslContinue", 1, "conversationId", conversationId, "payload", "")
        if not ccok or not ccdoc.done then
            return false, "SASL conversation failed to complete."
        end
    end
    return true
end

function MongoDB:delive(sock)
    tdelete(self.alives, sock)
    self.connections[sock.id] = sock
end

function MongoDB:on_socket_error(sock, token, err)
    --清空状态
    if sock == self.executer then
        self.executer = nil
        self:set_executer()
    end
    self:delive(sock)
    --设置重连
    timer_mgr:set_period(self.timer_id, SECOND_MS)
    event_mgr:fire_second(function()
        self:check_alive()
    end)
    for session_id, cmd in pairs(sock.sessions) do
        log_warn("[MongoDB][on_socket_error] drop cmd %s-%s)!", cmd, session_id)
        thread_mgr:response(session_id, false, err)
    end
    sock.sessions = {}
end

function MongoDB:decode_reply(slice)
    local doc = mdecode(slice)
    if doc.writeErrors then
        return false, doc.writeErrors[1].errmsg
    end
    if doc.writeConcernError then
        return false, doc.writeConcernError.errmsg
    end
    if doc.ok == 1 then
        return true, doc
    end
    return false, doc.errmsg or doc["$err"]
end

function MongoDB:on_socket_recv(sock, token, buff)
    if #buff <= OP_MSG_HLEN then
        return
    end
    --skip length + request_id
    local pos = 8 + 1
    local session_id, opcode, flags, payload, xpos = sunpack("<I4I4I4B", buff, pos)
    if opcode ~= OP_MSG_CODE then
        log_warn("[MongoDB][on_socket_recv] Unsupported opcode %s)!", opcode)
        return
    end
    if flags > 0 and (flags & OP_CHECKSUM ~= 0 or flags ^ OP_MORE_COME ~= 0) then
        log_warn("[MongoDB][on_socket_recv] Unsupported OP_MSG flag %s)!", flags)
        return
    end
    if payload ~= 0 then
        log_warn("Unsupported OP_MSG payload type: %d", payload)
        return
    end
    if session_id > 0 then
        self.res_counter:count_increase()
        local succ, doc = self:decode_reply(buff:sub(xpos))
        thread_mgr:response(session_id, succ, doc)
    end
end

function MongoDB:op_msg(sock, bsonv, cmd)
    if not sock then
        return false, "db not connected"
    end
    local tick = lclock_ms()
    local len = OP_MSG_HLEN + #bsonv
    local session_id = thread_mgr:build_session_id()
    local buff = spack("<I4I4I4I4I4B", len, session_id, 0, OP_MSG_CODE, 0, 0)
    if not sock:send(buff .. bsonv) then
        return false, "send failed"
    end
    sock.sessions[session_id] = cmd
    self.req_counter:count_increase()
    local _<close> = qdefer(function()
        sock.sessions[session_id] = nil
        local utime = lclock_ms() - tick
        if utime > FAST_MS then
            log_warn("[MongoDB][op_msg] cmd (%s:%s) execute so big %s!", cmd, session_id, utime)
        end
    end)
    return thread_mgr:yield(session_id, sformat("mongo_op:%s", cmd), DB_TIMEOUT)
end

function MongoDB:adminCommand(sock, cmd, cmd_v, ...)
    local bsonv = mencode_o(cmd, cmd_v, "$db", "admin", ...)
    return self:op_msg(sock, bsonv, cmd)
end

function MongoDB:runCommand(cmd, cmd_v, ...)
    local bsonv = mencode_o(cmd, cmd_v or 1, "$db", self.name, ...)
    return self:op_msg(self.executer, bsonv, cmd)
end

function MongoDB:sendCommand(cmd, cmd_v, ...)
    local sock = self.executer
    if sock then
        local bsonv = mencode_o(cmd, cmd_v or 1, "$db", self.name, "writeConcern", {w=0}, ...)
        local buff = spack("<I4I4I4I4I4B", OP_MSG_HLEN + #bsonv, 0, 0, OP_MSG_CODE, 0, 0)
        sock:send(buff .. bsonv)
    end
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
    return self:runCommand("insert", co_name, "documents", { doc })
end

function MongoDB:update(co_name, update, selector, upsert, multi)
    local cmd_data = { q = selector, u = update, upsert = upsert, multi = multi }
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
