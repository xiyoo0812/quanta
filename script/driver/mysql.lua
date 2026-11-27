--mysql.lua
local Socket        = import("driver/socket.lua")

local lsha1         = tls.sha1
local sgsub         = string.gsub
local log_err       = logger.err
local log_info      = logger.info
local sformat       = string.format
local tinsert       = table.insert
local terase        = table.erase
local mrandom       = qmath.random
local lnext_id      = luakit.next_id
local lxor_byte     = codec.xor_byte
local qhash         = codec.hash_code
local mysqlcodec    = codec.mysqlcodec
local make_timer    = quanta.make_timer
local make_functer  = quanta.make_functer
local makechan      = quanta.make_channel

local thread_mgr    = quanta.get("thread_mgr")
local update_mgr    = quanta.get("update_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local FAST_MS       = quanta.enum("PeriodTime", "FAST_MS")
local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")
local DBCALL_TO     = quanta.enum("NetwkTime", "DB_CALL_TIMEOUT")
local CONNECT_TO    = quanta.enum("NetwkTime", "CONNECT_TIMEOUT")

local POOL_COUNT    = environ.number("QUANTA_DB_POOL_COUNT", 3)

-- constants
local COM_QUERY         = 0x03
local COM_CONNECT       = 0x0b
local COM_PING          = 0x0e
local COM_STMT_PREPARE  = 0x16
local COM_STMT_EXECUTE  = 0x17

local MysqlDB = class()
local prop = property(MysqlDB)
prop:reader("name", "")         --dbname
prop:reader("user", nil)        --user
prop:reader("timer", nil)       --timer
prop:reader("passwd", nil)      --passwd
prop:reader("executer", nil)    --执行者
prop:reader("rcfunctor", nil)   --rcfunctor
prop:reader("connections", {})  --connections
prop:reader("stmt_querys", {})  --预处理列表
prop:reader("alives", {})       --alives

function MysqlDB:__init(conf)
    self.name = conf.db
    self.user = conf.user
    self.passwd = conf.passwd
    self.timer = make_timer()
    --update
    update_mgr:attach_hour(self)
    --setup
    thread_mgr:fork(function()
        self:set_options(conf.opts)
        if self:init_database(conf.hosts) then
            self:setup_pool(conf.hosts)
        end
    end)
end

--用临时连接连管理端(不指定库)建库, 成功后关闭临时连接
function MysqlDB:init_database(hosts)
    local _, host = next(hosts)
    if not host then
        log_err("[MysqlDB][init_database] hosts is empty")
        return false
    end
    --临时连接用负数 id, 与连接池区分
    local socket = Socket(self, host[1], host[2])
    socket:set_id(1)
    --mysql 不指定库时连到管理端
    local database = self.name
    self.name = ""
    --登录
    if not self:login(socket) then
        return false
    end
    local sql = sformat("create database if not exists %s", database)
    local sok, serr = self:request_on(socket, COM_QUERY, "mysql create db", sql)
    if not sok then
        log_err("[MysqlDB][init_database]: create database {} failed: {}", database, serr)
        self:close()
        return false
    end
    log_info("[MysqlDB][init_database] init database {} success", database)
    self.name = database
    self:close()
    return true
end

function MysqlDB:close()
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

function MysqlDB:set_options(opts)
end

function MysqlDB:set_executer(id)
    local count = #self.alives
    if count > 0 then
        local index = qhash(id or mrandom(), count)
        self.executer = self.alives[index]
        return true
    end
    return false
end

function MysqlDB:on_hour()
    for _, sock in pairs(self.alives) do
        self:request_on(sock, COM_PING, "mysql ping")
    end
end

function MysqlDB:setup_pool(hosts)
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
    self.rcfunctor = make_functer("check_alive", CONNECT_TO)
    self.timer:register(FAST_MS, SECOND_MS, -1, function()
        self.rcfunctor:run(self)
    end)
end

function MysqlDB:check_alive()
    if next(self.connections) then
        local channel = makechan("check mysql")
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

function MysqlDB:login(socket)
    local id, ip, port = socket.id, socket.ip, socket.port
    if not socket:connect(ip, port) then
        log_err("[MysqlDB][login] connect db({}:{}:{}) failed!", ip, port, id)
        return false
    end
    local ok, res = self:auth(socket)
    if not ok then
        socket:close()
        self:delive(socket)
        log_err("[MysqlDB][login] auth db({}:{}:{}) auth failed! because: {}", ip, port, id, res)
        return false
    end
    self.connections[id] = nil
    tinsert(self.alives, socket)
    log_info("[MysqlDB][login] login db({}:{}:{}) success!", ip, port, id)
    return true, SUCCESS
end

function MysqlDB:auth(socket)
    local session_id = lnext_id()
    socket:set_codec(mysqlcodec(session_id))
    local charset, scramble1, scramble2 = thread_mgr:yield(session_id, "mysql server auth", DBCALL_TO)
    local scramble = scramble1 .. scramble2
    local stage1 = lsha1(self.passwd)
    local stage2 = lsha1(scramble .. lsha1(stage1))
    local auth_passwd = lxor_byte(stage1, stage2)
    if not socket:send_data(COM_CONNECT, session_id, charset, self.user, auth_passwd, self.name) then
        return false, "send failed"
    end
    return thread_mgr:yield(session_id, "mysql client auth", DBCALL_TO)
end

function MysqlDB:delive(sock)
    sock.stmts = {}
    terase(self.alives, sock)
    self.connections[sock.id] = sock
end

function MysqlDB:on_socket_error(sock, token, err)
    --清空状态
    if sock == self.executer then
        self.executer = nil
        self:set_executer()
    end
    self:delive(sock)
    --设置重连
    self.timer:change_period(SECOND_MS)
end

function MysqlDB:on_socket_recv(socket, session_id, ...)
    if session_id > 0 then
        thread_mgr:response(session_id, ...)
    end
end

function MysqlDB:request_on(sock, cmd, quote, ...)
    if not sock then
        return false, "db not connected"
    end
    local session_id = lnext_id()
    if sock:send_data(cmd, session_id, ...) then
        return thread_mgr:yield(session_id, quote, DBCALL_TO)
    end
    return false, "send request failed"
end

function MysqlDB:request(cmd, quote, ...)
    return self:request_on(self.executer, cmd, quote, ...)
end

function MysqlDB:get_record_field(rdsets, field, rdset_index, rd_index)
    local rdset = rdsets[rdset_index or 1]
    if rdset then
        local record = rdset[rd_index or 1]
        if record then
            return record[field]
        end
    end
end

function MysqlDB:query(query)
    return self:request(COM_QUERY, "mysql query", query)
end

-- 注册预处理语句
function MysqlDB:prepare(name, sql)
    self.stmt_querys[name] = sql
    return true
end

function MysqlDB:prepare_check(name, sock)
    sock = sock or self.executer
    if not sock then
        return false, "db not connected"
    end
    local stmt_id = sock.stmts[name]
    if stmt_id then
        return true, stmt_id
    end
    local query = self.stmt_querys[name]
    if not query then
        return false, "prepare statement not found"
    end
    local ok, stmtid_or_err = self:request_on(sock, COM_STMT_PREPARE, "mysql prepare", query)
    if not ok then
        return false, stmtid_or_err
    end
    sock.stmts[name] = stmtid_or_err
    return true, stmtid_or_err
end

--执行预处理语句
function MysqlDB:execute(name, ...)
    local sock = self.executer
    local ok, stmt_id = self:prepare_check(name, sock)
    if not ok then
        return false, stmt_id
    end
    return self:request_on(sock, COM_STMT_EXECUTE, "mysql execute", stmt_id, ...)
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

function MysqlDB:escape_sql(str)
    return sformat("'%s'", sgsub(str, "[\0\b\n\r\t\26\\\'\"]", escape_map))
end

return MysqlDB
