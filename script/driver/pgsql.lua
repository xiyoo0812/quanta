--pgsql.lua
local Socket        = import("driver/socket.lua")

local log_err       = logger.err
local log_info      = logger.info
local spack         = string.pack
local sgsub         = string.gsub
local sformat       = string.format
local sgmatch       = string.gmatch
local tinsert       = table.insert
local terase        = table.erase
local mrandom       = qmath.random
local lnext_id      = luakit.next_id

local lmd5          = ssl.md5
local lsha256       = ssl.sha256
local lxor_byte     = ssl.xor_byte
local lrandomkey    = ssl.randomkey
local lb64encode    = ssl.b64_encode
local lb64decode    = ssl.b64_decode
local lhmac_sha256  = ssl.hmac_sha256
local pbkdf2_sha256 = ssl.pbkdf2_sha256

local qhash         = codec.hash_code
local pgsqlcodec    = codec.pgsqlcodec

local make_timer    = quanta.make_timer
local make_functer  = quanta.make_functer
local makechan      = quanta.make_channel

local thread_mgr    = quanta.get("thread_mgr")
local update_mgr    = quanta.get("update_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")
local DB_TIMEOUT    = quanta.enum("NetwkTime", "DB_CALL_TIMEOUT")
local POOL_COUNT    = environ.number("QUANTA_DB_POOL_COUNT", 1)

local AUTH_TYPE     = codec.auth_type_t
local REQUEST_CMD   = codec.pgsql_type_f

local ZERO_BIT2     = spack(">h", 0)
local ZERO_BIT4     = spack(">i", 0)

local PgsqlDB = class()
local prop = property(PgsqlDB)
prop:reader("name", "")         --dbname
prop:reader("user", nil)        --user
prop:reader("timer", nil)       --timer
prop:reader("passwd", nil)      --passwd
prop:reader("salted_pass", nil) --salted_pass
prop:reader("executer", nil)    --执行者
prop:reader("rcfunctor", nil)   --rcfunctor
prop:reader("connections", {})  --connections
prop:reader("stmt_querys", {})  --预处理列表
prop:reader("alives", {})       --alives

function PgsqlDB:__init(conf)
    self.name = conf.db
    self.user = conf.user
    self.passwd = conf.passwd
    self.timer = make_timer()
    --setup
    self:set_options(conf.opts)
    self:setup_pool(conf.hosts)
    --update
    update_mgr:attach_hour(self)
end

function PgsqlDB:close()
    for _, sock in pairs(self.alives) do
        sock:close()
    end
    for _, sock in pairs(self.connections) do
        sock:close()
    end
    self.timer:unregister()
    self.connections = {}
    self.stmt_querys = {}
    self.alives = {}
end

function PgsqlDB:set_options(opts)
end

function PgsqlDB:set_executer(id)
    local count = #self.alives
    if count > 0 then
        local index = qhash(id or mrandom(), count)
        self.executer = self.alives[index]
        return true
    end
    return false
end

function PgsqlDB:on_hour()
    for _, sock in pairs(self.alives) do
        self.executer = sock
        self:request(REQUEST_CMD.SYNC, "pgsql ping")
    end
end

function PgsqlDB:setup_pool(hosts)
    if not next(hosts) then
        log_err("[PgsqlDB][setup_pool] pgsql config err: hosts is empty")
        return
    end
    local count = 1
    for _, host in pairs(hosts) do
        for _ = 1, POOL_COUNT do
            local socket = Socket(self, host[1], host[2])
            self.connections[count] = socket
            socket:set_id(count)
            socket.stmts = {}
            count = count + 1
        end
    end
    self.rcfunctor = make_functer(self.check_alive)
    self.timer:loop(SECOND_MS, function()
        self.rcfunctor:call(self)
    end)
end

function PgsqlDB:check_alive()
    if next(self.connections) then
        local channel = makechan("check pgsql")
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

function PgsqlDB:login(socket)
    local id, ip, port = socket.id, socket.ip, socket.port
    if not socket:connect(ip, port) then
        log_err("[PgsqlDB][login] connect db({}:{}:{}) failed!", ip, port, id)
        return false
    end
    log_info("[PgsqlDB][login] connect db({}:{}:{})!", ip, port, id)
    local ok, err = self:auth(socket)
    if not ok then
        socket:close()
        self:delive(socket)
        log_err("[PgsqlDB][login] auth db({}:{}:{}) auth failed! because: {}", ip, port, id, err)
        return false
    end
    self.connections[id] = nil
    tinsert(self.alives, socket)
    log_info("[PgsqlDB][login] login db({}:{}:{}) success!", ip, port, id)
    return true, SUCCESS
end

function PgsqlDB:salt_password(password, salt, iter)
    if self.salted_pass then
        return self.salted_pass
    end
    local output = pbkdf2_sha256(password, salt, iter)
    self.salted_pass = output
    return output
end

function PgsqlDB:md5_auth(socket, salt)
    local user = sgsub(sgsub(self.user, '=', '=3D'), ',', '=2C')
    local passwd = sgsub(sgsub(self.passwd, '=', '=3D'), ',', '=2C')
    local md5_passwd = sformat("md5%s\0",  lmd5(lmd5(passwd .. user, 1) .. salt, 1))
    local ok, auth_type = self:auth_request(socket, REQUEST_CMD.PASSWORD, "pgsql md5 auth", md5_passwd)
    if not ok or auth_type ~= AUTH_TYPE.OK then
        return false, sformat("auth md5 failed: %s", auth_type)
    end
    return ok
end

function PgsqlDB:sasl_auth(socket)
    local nonce = lrandomkey(24, 1)
    local user = sgsub(sgsub(self.user, '=', '=3D'), ',', '=2C')
    local cli_first_bare = sformat("n=%s,r=%s", user, nonce)
    local init_data = sformat("n,,%s", cli_first_bare)
    local sasl_start = sformat("SCRAM-SHA-256\0%s%s", spack(">i", #init_data), init_data)
    local sok, aauth_type, svr_first_bare = self:auth_request(socket, REQUEST_CMD.PASSWORD, "pgsql sasl start", sasl_start)
    if not sok or aauth_type ~= AUTH_TYPE.SASL_CONTINUE then
        return false, sformat("auth asal start failed: %s", aauth_type)
    end
    local payload = {}
    for k, v in sgmatch(svr_first_bare, "(%w+)=([^,]*)") do
        payload[k] = v
    end
    local iterations = tonumber(payload.i)
    local passwd = sgsub(sgsub(self.passwd, '=', '=3D'), ',', '=2C')
    local salted_pass = self:salt_password(passwd, lb64decode(payload.s), iterations)
    local client_key = lhmac_sha256(salted_pass, "Client Key")
    local without_proof = sformat("c=biws,r=%s", payload.r)
    local auth_msg = sformat("%s,%s,%s", cli_first_bare, svr_first_bare, without_proof)
    local client_sig = lhmac_sha256(lsha256(client_key), auth_msg)
    local client_xor_sig = lxor_byte(client_key, client_sig)
    local client_proof = sformat("%s,p=%s", without_proof, lb64encode(client_xor_sig))
    local cok, cauth_type, svr_final_bare = self:auth_request(socket, REQUEST_CMD.PASSWORD, "pgsql sasl continue", client_proof)
    if not cok or cauth_type ~= AUTH_TYPE.OK then
        return false, sformat("auth asal continue failed: %s", cauth_type)
    end
    for k, v in sgmatch(svr_final_bare, "(%w+)=([^,]*)") do
        payload[k] = v
    end
    local server_key = lhmac_sha256(salted_pass, "Server Key")
    local server_sig = lb64encode(lhmac_sha256(server_key, auth_msg))
    if server_sig ~= payload.v then
        return false,  "auth asal final failed"
    end
    return true
end

function PgsqlDB:auth(socket)
    socket:set_codec(pgsqlcodec())
    local ok, method, args = self:auth_request(socket, REQUEST_CMD.STARTUP, "pgsql auth", self.user, self.name)
    if not ok then
        return false, sformat("auth failed: %s", method)
    end
    if method == AUTH_TYPE.SASL then
        return self:sasl_auth(socket)
    end
    if method == AUTH_TYPE.MD5 then
        return self:md5_auth(socket, args)
    end
    return false, "auth method not support"
end

function PgsqlDB:delive(sock)
    sock.stmts = {}
    terase(self.alives, sock)
    self.connections[sock.id] = sock
end

function PgsqlDB:on_socket_error(sock, token, err)
    --清空状态
    if sock == self.executer then
        self.executer = nil
        self:set_executer()
    end
    self:delive(sock)
    --设置重连
    self.timer:change_period(SECOND_MS)
end

function PgsqlDB:on_socket_recv(socket, session_id, ...)
    if session_id > 0 then
        thread_mgr:response(session_id, ...)
    end
end

function PgsqlDB:auth_request(socket, cmd, quote, ...)
    local session_id = lnext_id()
    if socket:send_data(cmd, session_id, ...) then
        return thread_mgr:yield(session_id, quote, DB_TIMEOUT)
    end
    return false, "send request failed"
end

function PgsqlDB:request(cmd, quote, ...)
    if self.executer then
        local session_id = lnext_id()
        if self.executer:send_data(cmd, session_id, ...) then
            return thread_mgr:yield(session_id, quote, DB_TIMEOUT)
        end
    end
    return false, "send request failed"
end

function PgsqlDB:query(query)
    return self:request(REQUEST_CMD.QUERY, "pgsql query", query .. '\0')
end

function PgsqlDB:send(cmd, ...)
    self.executer:send_data(cmd, 0, ...)
end

-- 注册预处理语句
function PgsqlDB:prepare(name, sql)
    self.stmt_querys[name] = sformat("%s\0%s\0%s", name, sql, ZERO_BIT2)
    return true
end

function PgsqlDB:prepare_check(name)
    if not self.executer then
        return false, "db not connected"
    end
    if self.executer.stmts[name] then
        return true
    end
    local query = self.stmt_querys[name]
    if not query then
        return false, "prepare statement not found"
    end
    self:send(REQUEST_CMD.PARSE, query)
    local ok, res_err = self:request(REQUEST_CMD.SYNC, "pgsql prepare")
    if not ok then
        return false, res_err
    end
    self.executer.stmts[name] = true
    return true
end

--执行预处理语句
function PgsqlDB:execute(name, ...)
    if not self:prepare_check(name) then
        return false, "prepare statement not found"
    end
    local argfmt = ""
    local bind_args = {...}
    for _, val in pairs(bind_args) do
        local args = tostring(val)
        argfmt = argfmt .. spack(">i", #args) .. args
    end
    local bquery = sformat("%s\0%s\0%s%s%s%s", name, name, ZERO_BIT2, spack(">h", #bind_args), argfmt, ZERO_BIT2)
    self:send(REQUEST_CMD.BIND, bquery)
    self:send(REQUEST_CMD.DISCRIBE, 'S' .. name .. '\0')
    self:send(REQUEST_CMD.EXECUTE, sformat("%s\0%s", name, ZERO_BIT4))
    return self:request(REQUEST_CMD.SYNC, "pgsql execute")
end

local escape_map = {
    ['\0'] = "\\0",
    ['\b'] = "\\b",
    ['\n'] = "\\n",
    ['\r'] = "\\r",
    ['\t'] = "\\t",
    ['\26'] = "\\Z",
    ['\\'] = "\\\\",
    ["'"] = "\\'",
    ['"'] = '\\"',
}

function PgsqlDB:escape_sql(str)
    return sformat("'%s'", sgsub(str, "[\0\b\n\r\t\26\\\'\"]", escape_map))
end

return PgsqlDB
