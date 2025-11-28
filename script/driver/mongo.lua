
--mongo.lua
local Socket        = import("driver/socket.lua")

local log_err       = logger.err
local log_info      = logger.info
local tjoin         = table.join
local tinsert       = table.insert
local tunpack       = table.unpack
local terase        = table.erase
local sgsub         = string.gsub
local sformat       = string.format
local sgmatch       = string.gmatch
local mrandom       = qmath.random
local mtointeger    = math.tointeger
local bint64        = bson.int64
local qhash         = codec.hash_code
local make_timer    = quanta.make_timer
local make_functer  = quanta.make_functer
local makechan      = quanta.make_channel

local lmd5          = ssl.md5
local lsha1         = ssl.sha1
local lxor_byte     = ssl.xor_byte
local lrandomkey    = ssl.randomkey
local lb64encode    = ssl.b64_encode
local lb64decode    = ssl.b64_decode
local lhmac_sha1    = ssl.hmac_sha1
local pbkdf2_sha1   = ssl.pbkdf2_sha1
local lnext_id      = luakit.next_id

local thread_mgr    = quanta.get("thread_mgr")
local update_mgr    = quanta.get("update_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")
local DB_TIMEOUT    = quanta.enum("NetwkTime", "DB_CALL_TIMEOUT")
local POOL_COUNT    = environ.number("QUANTA_DB_POOL_COUNT", 3)

local MongoDB = class()
local prop = property(MongoDB)
prop:reader("name", "")         --dbname
prop:reader("user", nil)        --user
prop:reader("timer", nil)       --timer
prop:reader("passwd", nil)      --passwd
prop:reader("salted_pass", nil) --salted_pass
prop:reader("executer", nil)    --执行者
prop:reader("rcfunctor", nil)   --rcfunctor
prop:reader("connections", {})  --connections
prop:reader("alives", {})       --alives

function MongoDB:__init(conf)
    self.name = conf.db
    self.user = conf.user
    self.passwd = conf.passwd
    self.timer = make_timer()
    self.codec = bson.mongocodec()
    self:set_options(conf.opts)
    self:setup_pool(conf.hosts)
    --attach_hour
    update_mgr:attach_hour(self)
end

function MongoDB:close()
    for sock in pairs(self.alives) do
        sock:close()
    end
    for sock in pairs(self.connections) do
        sock:close()
    end
    self.timer:unregister()
    self.connections = {}
    self.alives = {}
end

function MongoDB:set_options(opts)
end

function MongoDB:setup_pool(hosts)
    if not next(hosts) then
        log_err("[MongoDB][setup_pool] mongo config err: hosts is empty")
        return
    end
    local count = 1
    for _, host in pairs(hosts) do
        for _ = 1, POOL_COUNT do
            local socket = Socket(self, host[1], host[2])
            self.connections[count] = socket
            socket:set_id(count)
            count = count + 1
        end
    end
    self.rcfunctor = make_functer(self.check_alive)
    self.timer:loop(SECOND_MS, function()
        self.rcfunctor:call(self)
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
        local channel = makechan("check mongo")
        for _, sock in pairs(self.connections) do
            channel:push(function()
                return self:login(sock)
            end)
        end
        if channel:execute(true) then
            self.timer:change_period(SECOND_10_MS)
        end
        self:set_executer()
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
    local ok, err = socket:connect(ip, port)
    if not ok then
        log_err("[MongoDB][login] connect db({}:{}:{}:{}) failed: {}!", ip, port, self.name, id, err)
        return false
    end
    socket:set_codec(self.codec)
    if self.user and self.passwd then
        local aok, aerr = self:auth(socket, self.user, self.passwd)
        if not aok then
            log_err("[MongoDB][login] auth db({}:{}:{}:{}) failed! because: {}", ip, port, self.name, id, aerr)
            self:delive(socket)
            socket:close()
            return false
        end
    end
    self.connections[id] = nil
    tinsert(self.alives, socket)
    log_info("[MongoDB][login] connect db({}:{}:{}:{}) success!", ip, port,self.name, id)
    return true, SUCCESS
end

function MongoDB:salt_password(password, salt, iter)
    if self.salted_pass then
        return self.salted_pass
    end
    local output = pbkdf2_sha1(password, salt, iter)
    self.salted_pass = output
    return output
end

function MongoDB:auth(sock, username, password)
    local nonce = lrandomkey(16, 1)
    local user = sgsub(sgsub(username, '=', '=3D'), ',', '=2C')
    local first_bare = sformat("n=%s,r=%s", user, nonce)
    local sasl_payload = lb64encode("n,," .. first_bare)
    local sok, sdoc = self:adminCommand(sock, "saslStart", 1, "autoAuthorize", 1, "mechanism", "SCRAM-SHA-1", "payload", sasl_payload)
    if not sok then
        return sok, sdoc
    end
    local payload = {}
    local conversationId = sdoc.conversationId
    local payload_start = lb64decode(sdoc.payload)
    for k, v in sgmatch(payload_start, "(%w+)=([^,]*)") do
        payload[k] = v
    end
    local iterations = tonumber(payload.i)
    local pbkdf2_key = lmd5(sformat("%s:mongo:%s", username, password), 1)
    local salted_pass = self:salt_password(pbkdf2_key, lb64decode(payload.s), iterations)
    local client_key = lhmac_sha1(salted_pass, "Client Key")
    local without_proof = sformat("c=biws,r=%s", payload.r)
    local auth_msg = sformat("%s,%s,%s", first_bare, payload_start, without_proof)
    local client_sig = lhmac_sha1(lsha1(client_key), auth_msg)
    local client_xor_sig = lxor_byte(client_key, client_sig)
    local client_proof = sformat("%s,p=%s", without_proof, lb64encode(client_xor_sig))
    local client_final = lb64encode(client_proof)
    local cok, cdoc = self:adminCommand(sock, "saslContinue", 1, "conversationId", conversationId, "payload", client_final)
    if not cok then
        return cok, cdoc
    end
    local payload_continue = lb64decode(cdoc.payload)
    for k, v in sgmatch(payload_continue, "(%w+)=([^,]*)") do
        payload[k] = v
    end
    local server_key = lhmac_sha1(salted_pass, "Server Key")
    local server_sig = lb64encode(lhmac_sha1(server_key, auth_msg))
    if payload.v ~= server_sig then
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
    terase(self.alives, sock)
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
    self.timer:change_period(SECOND_MS)
end

function MongoDB:decode_reply(result)
    if result.writeErrors then
        return false, result.writeErrors[1].errmsg
    end
    if result.writeConcernError then
        return false, result.writeConcernError.errmsg
    end
    if result.ok == 1 then
        return true, result
    end
    return false, result.errmsg or result["$err"]
end

function MongoDB:on_socket_recv(sock, session_id, result)
    if session_id > 0 then
        local succ, doc = self:decode_reply(result)
        thread_mgr:response(session_id, succ, doc)
    end
end

function MongoDB:op_msg(sock, session_id, cmd, ...)
    if not sock then
        return false, "db not connected"
    end
    if not sock:send_data(session_id, cmd, ...) then
        return false, "send failed"
    end
    return thread_mgr:yield(session_id, cmd, DB_TIMEOUT)
end

function MongoDB:adminCommand(sock, cmd, cmd_v, ...)
    local session_id = lnext_id()
    return self:op_msg(sock, session_id, cmd, cmd_v, "$db", "admin", ...)
end

function MongoDB:runCommand(cmd, cmd_v, ...)
    local session_id = lnext_id()
    return self:op_msg(self.executer, session_id, cmd, cmd_v or 1, "$db", self.name, ...)
end

function MongoDB:sendCommand(cmd, cmd_v, ...)
    self.executer:send_data(0, cmd, cmd_v or 1, "$db", self.name, "writeConcern", {w=0}, ...)
end

function MongoDB:drop_collection(co_name)
    return self:runCommand("drop", co_name)
end

-- 参数说明
-- indexes: {{key={open_id=1}, name="open_id", unique=true} }
-- indexes: {{key={open_id,1,platform_id,1}, name="open_id-platform_id", unique=true} }
function MongoDB:create_indexes(co_name, indexes)
    for _, index in pairs(indexes) do
        index.key = self:format_pairs(index.key)
    end
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
    local succ, reply = self:runCommand("find", co_name, "filter", query, "projection", projection, "limit", 1)
    if not succ then
        return succ, reply
    end
    local documents = reply.cursor.firstBatch
    if #documents > 0 then
        return succ, documents[1]
    end
    return succ
end

function MongoDB:format_pairs(args)
    if args then
        if type(next(args)) == "string" then
            return args
        end
        args.__order = true
        return args
    end
end

-- 参数说明
--sort: {k1=1} / {k1,1,k2,-1,k3,-1}
function MongoDB:find(co_name, query, projection, sortor, limit, skip)
    local fsortor = self:format_pairs(sortor)
    local succ, reply = self:runCommand("find", co_name, "filter", query, "projection", projection, "sort", fsortor, "limit", limit, "skip", skip)
    if not succ then
        return succ, reply
    end
    local results = {}
    local cursor = reply.cursor
    while cursor do
        local documents = cursor.firstBatch or cursor.nextBatch
        tjoin(documents, results)
        if not cursor.id or cursor.id == 0 then
            break
        end
        if limit and #results >= limit then
            break
        end
        local new_cur_id = bint64(cursor.id)
        local msucc, moreply = self:runCommand("getMore", new_cur_id, "collection", co_name, "batchSize", limit)
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

-- https://docs.mongodb.com/manual/reference/command/aggregate/
-- co_name: collection name || 1
-- pipeline: { { ["$match"]={pid = 123456} }, { ["$group"]={_id="date",count={["$sum"]=1}} } }
-- options: { [key, value] ... }，请参考文档
function MongoDB:aggregate(co_name, pipeline, options)
    return self:runCommand("aggregate", co_name, "pipeline", pipeline, tunpack(options or {}))
end

-- https://www.mongodb.com/zh-cn/docs/manual/reference/command/bulkWrite/
-- datas：{
--      //insert, 必须按下面的格式传入，额外的字段请参考文档
--      {"insert", "xxx", "document", {count=0}},
--      //delete, 必须按下面的格式传入，额外的字段请参考文档
--      {"delete", "xxx", "filter", {id = 2}, "multi", true},
--      //update, 必须按下面的格式传入，额外的字段请参考文档
--      {"update", "xxx", "updateMods", {["$set"] = {count = 2}}, "filter", {id = 2}, "multi", true},
--}
-- ordered: true/false, 顺序(默认)/并行执行，顺序则操作失败后停止执行返回失败；并行则所有操作完成后返回结果
-- options: { [key, value] ... }，请参考文档
-- bulkwrite不要超过1000个op
function MongoDB:bulkwrite(datas, ordered, options)
    local ns, indexs = {}, {}
    for _, data in ipairs(datas) do
        local fullns = sformat("%s.%s", self.name, data[2])
        local ns_idx = indexs[fullns]
        if not ns_idx then
            ns_idx = #ns
            indexs[fullns] = ns_idx
            ns[ns_idx + 1] = { ns = fullns }
        end
        data[2] = ns_idx
        data.__order = true
    end
    return self:adminCommand(self.executer, "bulkWrite", 1, "ops", datas, "nsInfo", ns, "ordered", ordered, tunpack(options or {}))
end

return MongoDB
