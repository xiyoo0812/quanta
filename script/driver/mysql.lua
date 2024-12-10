--mysql.lua
local Socket        = import("driver/socket.lua")

local lsha1         = ssl.sha1
local sgsub         = string.gsub
local log_err       = logger.err
local log_info      = logger.info
local sformat       = string.format
local tinsert       = table.insert
local tdelete       = qtable.delete
local mrandom       = qmath.random
local lxor_byte     = ssl.xor_byte
local qhash         = codec.hash_code
local mysqlcodec    = codec.mysqlcodec
local make_timer    = quanta.make_timer
local makechan      = quanta.make_channel

local thread_mgr    = quanta.get("thread_mgr")
local update_mgr    = quanta.get("update_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")
local DB_TIMEOUT    = quanta.enum("NetwkTime", "DB_CALL_TIMEOUT")
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
prop:reader("connections", {})  --connections
prop:reader("stmt_querys", {})  --预处理列表
prop:reader("alives", {})       --alives

function MysqlDB:__init(conf)
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
        self.executer = sock
        self:request(COM_PING, "mysql ping")
    end
end

function MysqlDB:setup_pool(hosts)
    if not next(hosts) then
        log_err("[MysqlDB][setup_pool] mysql config err: hosts is empty")
        return
    end
    local count = 1
    for _, host in pairs(hosts) do
        for c = 1, POOL_COUNT do
            local socket = Socket(self, host[1], host[2])
            self.connections[count] = socket
            socket.stmts = {}
            socket:set_id(count)
            count = count + 1
        end
    end
    self.timer:loop(SECOND_MS, function()
        self:check_alive()
    end)
end

function MysqlDB:check_alive()
    if next(self.connections) then
        thread_mgr:entry(self:address(), function()
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
        end)
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
    local session_id = thread_mgr:build_session_id()
    socket:set_codec(mysqlcodec(session_id))
    local charset, scramble1, scramble2 = thread_mgr:yield(session_id, "mysql server auth", DB_TIMEOUT)
    local scramble = scramble1 .. scramble2
    local stage1 = lsha1(self.passwd)
    local stage2 = lsha1(scramble .. lsha1(stage1))
    local auth_passwd = lxor_byte(stage1, stage2)
    if not socket:send_data(COM_CONNECT, session_id, charset, self.user, auth_passwd, self.name) then
        return false, "send failed"
    end
    return thread_mgr:yield(session_id, "mysql client auth", DB_TIMEOUT)
end

function MysqlDB:delive(sock)
    sock.stmts = {}
    tdelete(self.alives, sock)
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

function MysqlDB:request(cmd, quote, ...)
    if self.executer then
        local session_id = thread_mgr:build_session_id()
        if self.executer:send_data(cmd, session_id, ...) then
            return thread_mgr:yield(session_id, quote, DB_TIMEOUT)
        end
    end
    return false, "send request failed"
end

function MysqlDB:query(query)
    return self:request(COM_QUERY, "mysql query", query)
end

-- 注册预处理语句
function MysqlDB:prepare(name, sql)
    self.stmt_querys[name] = sql
    return true
end

function MysqlDB:prepare_check(name)
    if not self.executer then
        return false, "db not connected"
    end
    local stmt_id = self.executer.stmts[name]
    if stmt_id then
        return true, stmt_id
    end
    local query = self.stmt_querys[name]
    if not query then
        return false, "prepare statement not found"
    end
    local ok, stmtid_or_err = self:request(COM_STMT_PREPARE, "mysql prepare", query)
    if not ok then
        return true, stmtid_or_err
    end
    self.executer.stmts[name] = stmtid_or_err
    return true, stmtid_or_err
end

--执行预处理语句
function MysqlDB:execute(name, ...)
    local stmt_id = self:check_prepare(name)
    if not stmt_id then
        return false, "prepare statement not found"
    end
    return self:request(COM_STMT_EXECUTE, "mysql execute", stmt_id, ...)
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
