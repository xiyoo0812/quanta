--mysql.lua
import("driver/poll.lua")
local lcrypt        = require("lcrypt")
local Socket        = import("driver/socket.lua")
local QueueFIFO     = import("container/queue_fifo.lua")

local tonumber      = tonumber
local lsha1         = lcrypt.sha1
local ssub          = string.sub
local srep          = string.rep
local sgsub         = string.gsub
local sbyte         = string.byte
local schar         = string.char
local spack         = string.pack
local log_err       = logger.err
local log_info      = logger.info
local sformat       = string.format
local sunpack       = string.unpack
local tunpack       = table.unpack
local tinsert       = table.insert
local tointeger     = math.tointeger

local NetwkTime     = enum("NetwkTime")
local PeriodTime    = enum("PeriodTime")

local poll          = quanta.get("poll")
local timer_mgr     = quanta.get("timer_mgr")
local thread_mgr    = quanta.get("thread_mgr")

--charset编码
local CHARSET_MAP = {
    _default  = 0,
    big5      = 1,
    dec8      = 3,
    cp850     = 4,
    hp8       = 6,
    koi8r     = 7,
    latin1    = 8,
    latin2    = 9,
    swe7      = 10,
    ascii     = 11,
    ujis      = 12,
    sjis      = 13,
    hebrew    = 16,
    tis620    = 18,
    euckr     = 19,
    koi8u     = 22,
    gb2312    = 24,
    greek     = 25,
    cp1250    = 26,
    gbk       = 28,
    latin5    = 30,
    armscii8  = 32,
    utf8      = 33,
    ucs2      = 35,
    cp866     = 36,
    keybcs2   = 37,
    macce     = 38,
    macroman  = 39,
    cp852     = 40,
    latin7    = 41,
    utf8mb4   = 45,
    cp1251    = 51,
    utf16     = 54,
    utf16le   = 56,
    cp1256    = 57,
    cp1257    = 59,
    utf32     = 60,
    binary    = 63,
    geostd8   = 92,
    cp932     = 95,
    eucjpms   = 97,
    gb18030   = 248
}

-- constants
local COM_QUERY         = "\x03"
local COM_PING          = "\x0e"
local COM_STMT_PREPARE  = "\x16"
local COM_STMT_EXECUTE  = "\x17"
local COM_STMT_CLOSE    = "\x19"
local COM_STMT_RESET    = "\x1a"

local CURSOR_TYPE_NO_CURSOR = 0x00
local SERVER_MORE_RESULTS_EXISTS = 8

-- mysql field value type converters
local converters = {
    [0x01] = tonumber,  -- tiny
    [0x02] = tonumber,  -- short
    [0x03] = tonumber,  -- long
    [0x04] = tonumber,  -- float
    [0x05] = tonumber,  -- double
    [0x08] = tonumber,  -- long long
    [0x09] = tonumber,  -- int24
    [0x0d] = tonumber,  -- year
    [0xf6] = tonumber,  -- newdecimal
}

local function _get_byte1(data, i)
    return sbyte(data, i), i + 1
end

local function _get_int1(data, i, is_signed)
    if not is_signed then
        return sunpack("<I1", data, i)
    end
    return sunpack("<i1", data, i)
end

local function _get_byte2(data, i)
    return sunpack("<I2", data, i)
end

local function _get_int2(data, i, is_signed)
    if not is_signed then
        return sunpack("<I2", data, i)
    end
    return sunpack("<i2", data, i)
end

local function _get_byte3(data, i)
    return sunpack("<I3", data, i)
end

local function _get_int3(data, i, is_signed)
    if not is_signed then
        return sunpack("<I3", data, i)
    end
    return sunpack("<i3", data, i)
end

local function _get_byte4(data, i)
    return sunpack("<I4", data, i)
end

local function _get_int4(data, i, is_signed)
    if not is_signed then
        return sunpack("<I4", data, i)
    end
    return sunpack("<i4", data, i)
end

local function _get_byte8(data, i)
    return sunpack("<I8", data, i)
end

local function _get_int8(data, i, is_signed)
    if not is_signed then
        return sunpack("<I8", data, i)
    end
    return sunpack("<i8", data, i)
end

local function _get_float(data, i)
    return sunpack("<f", data, i)
end

local function _get_double(data, i)
    return sunpack("<d", data, i)
end

local function _from_length_coded_bin(data, pos)
    local first = sbyte(data, pos)
    if not first then
        return nil, pos
    end
    if first >= 0 and first <= 250 then
        return first, pos + 1
    end
    if first == 251 then
        return nil, pos + 1
    end
    if first == 252 then
        pos = pos + 1
        return _get_byte2(data, pos)
    end
    if first == 253 then
        pos = pos + 1
        return _get_byte3(data, pos)
    end
    if first == 254 then
        pos = pos + 1
        return _get_byte8(data, pos)
    end
    return false, pos + 1
end

local function _get_datetime(data, pos)
    local len, year, month, day, hour, minute, second
    local value
    len, pos = _from_length_coded_bin(data, pos)
    if len == 7 then
        year, month, day, hour, minute, second, pos = string.unpack("<I2BBBBB", data, pos)
        value = sformat("%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, minute, second)
    else
        value = "2017-09-09 20:08:09"
        pos = pos + len
    end
    return value, pos
end

local function _from_cstring(data, pos)
    return sunpack("z", data, pos)
end

local function _from_length_coded_str(data, pos)
    local len
    len, pos = _from_length_coded_bin(data, pos)
    if len == nil then
        return nil, pos
    end
    return ssub(data, pos, pos + len - 1), pos + len
end

local function _set_byte2(n)
    return spack("<I2", n)
end

local function _set_byte3(n)
    return spack("<I3", n)
end

local function _set_byte4(n)
    return spack("<I4", n)
end

local function _set_byte8(n)
    return spack("<I8", n)
end

local function _set_int8(n)
    return spack("<i8", n)
end

local function _set_float(n)
    return spack("<f", n)
end

local function _set_double(n)
    return spack("<d", n)
end

local function _set_length_coded_bin(n)
    if n < 251 then
        return schar(n)
    end
    if n < (1 << 16) then
        return spack("<BI2", 0xfc, n)
    end
    if n < (1 << 24) then
        return spack("<BI3", 0xfd, n)
    end
    return spack("<BI8", 0xfe, n)
end

--字段类型参考
--https://dev.mysql.com/doc/dev/mysql-server/8.0.12/binary__log__types_8h.html
--enum_field_types 枚举类型定义
local _binary_parser = {
    [0x01] = _get_int1,
    [0x02] = _get_int2,
    [0x03] = _get_int4,
    [0x04] = _get_float,
    [0x05] = _get_double,
    [0x07] = _get_datetime,
    [0x08] = _get_int8,
    [0x09] = _get_int3,
    [0x0c] = _get_datetime,
    [0x0f] = _from_length_coded_str,
    [0x10] = _from_length_coded_str,
    [0xf9] = _from_length_coded_str,
    [0xfa] = _from_length_coded_str,
    [0xfb] = _from_length_coded_str,
    [0xfc] = _from_length_coded_str,
    [0xfd] = _from_length_coded_str,
    [0xfe] = _from_length_coded_str
}

--ok报文
local function _parse_ok_packet(packet)
    --1 byte 0x00报文标志(不处理)
    --1-9 byte 受影响行数
    local affrows, pos = _from_length_coded_bin(packet, 2)
    --1-9 byte 索引ID值
    local index, pos1 = _from_length_coded_bin(packet, pos)
    --2 byte 服务器状态
    local status, pos2 = _get_byte2(packet, pos1)
    --2 byte 警告数量编号
    local warncnt, pos3 = _get_byte2(packet, pos)
    --n byte 服务器消息
    local msg = ssub(packet, pos3)
    return { affected_rows = affrows, insert_id = index, server_status = status, warning_count = warncnt, message = msg }
end

--eof报文
local function _parse_eof_packet(packet)
    --1 byte 0xfe报文标志(不处理)
    --2 byte 警告数量编号
    local warning_count, pos = _get_byte2(packet, 2)
    --2 byte 状态标志位
    local status_flags = _get_byte2(packet, pos)
    return warning_count, status_flags
end

--error报文
local function _parse_err_packet(packet)
    --1 byte 0xff报文标志(不处理)
    --2 byte 错误编号
    local errno, pos = _get_byte2(packet, 2)
    --1 byte 服务器状态标识，恒为#(不处理)
    --5 byte 服务器状态
    local sqlstate = ssub(packet, pos + 1, pos + 6 - 1)
    local message = ssub(packet, pos + 6)
    return errno, message, sqlstate
end

--result_set报文
local function _parse_result_set_header_packet(packet)
    --1-9 byte Field结构计数
    local field_count, pos = _from_length_coded_bin(packet, 1)
    --1-9 byte 额外信息
    local extra, pos2 = _from_length_coded_bin(packet, pos)
    return field_count, extra
end

--field 报文结构
local function _parse_field_packet(data)
    --n byte 目录名称
    local _, pos = _from_length_coded_str(data, 1)
    --n byte 数据库名称
    local _, pos1 = _from_length_coded_str(data, pos)
    --n byte 数据表名称
    local _, pos2 = _from_length_coded_str(data, pos1)
    --n byte 数据表原始名称
    local _, pos3 = _from_length_coded_str(data, pos2)
    --n byte 列（字段）名称
    local name, pos4 = _from_length_coded_str(data, pos3)
    --n byte 列（字段）原始名称
    local _, pos5 = _from_length_coded_str(data, pos4)
    --1 byte 填充值(不处理)
    --2 byte 字符编码(不处理)
    --4 byte 列（字段）长度(不处理)
    pos5 = pos5 + 7
    --1 byte 列（字段）类型
    local type = sbyte(data, pos5)
    pos5 = pos5 + 1
    --2 byte 列（字段）标志
    local flags = _get_byte2(data, pos5)
    -- https://mariadb.com/kb/en/resultset/
    local is_signed = (flags & 0x20 == 0) and true or false
    return { type = type, is_signed = is_signed, name = name }
end

--row_data报文
local function _parse_row_data_packet(data, cols, compact)
    local row = {}
    local pos = 1
    for i, col in ipairs(cols) do
        local value
        value, pos = _from_length_coded_str(data, pos)
        if value ~= nil then
            local conv = converters[col.type]
            if conv then
                value = conv(value)
            end
        end
        if compact then
            row[i] = value
        else
            row[col.name] = value
        end
    end
    return row
end

--参数字段类型转换
local store_types = {
    ["number"] = function(v)
        if not tointeger(v) then
            return _set_byte2(0x05), _set_double(v)
        else
            return _set_byte2(0x08), _set_int8(v)
        end
    end,
    ["string"] = function(v)
        return _set_byte2(0x0f), _set_length_coded_bin(#v) .. v
    end,
    --bool转换为0,1
    ["boolean"] = function(v)
        if v then
            return _set_byte2(0x01), schar(1)
        else
            return _set_byte2(0x01), schar(0)
        end
    end,
    ["nil"] = function(v)
        return _set_byte2(0x06), ""
    end
}

local function _compute_token(password, scramble)
    if password == "" then
        return ""
    end
    local stage1 = lsha1(password)
    local stage2 = lsha1(stage1)
    local stage3 = lsha1(scramble .. stage2)
    local i = 0
    return sgsub(stage3, ".", function(x)
        i = i + 1
        return schar(sbyte(x) ~ sbyte(stage1, i))
    end)
end

local function _compose_stmt_execute(self, stmt, cursor_type, args)
    local arg_num = #args
    if arg_num ~= stmt.param_count then
        error("require stmt.param_count " .. stmt.param_count .. " get arg_num " .. arg_num)
    end
    self.packet_no = -1
    local cmd_packet = spack("<c1I4BI4", COM_STMT_EXECUTE, stmt.prepare_id, cursor_type, 0x01)
    if arg_num > 0 then
        local f, ts, vs
        local types_buf = ""
        local values_buf = ""
        --生成NULL位图
        local null_count = (arg_num + 7) // 8
        local null_map = ""
        local field_index = 1
        for i = 1, null_count do
            local byte = 0
            for j = 0, 7 do
                if field_index < arg_num then
                    if args[field_index] == nil then
                        byte = byte | (1 << j)
                    else
                        byte = byte | (0 << j)
                    end
                end
                field_index = field_index + 1
            end
            null_map = null_map .. schar(byte)
        end
        for i = 1, arg_num do
            local v = args[i]
            f = store_types[type(v)]
            if not f then
                error("invalid parameter type", type(v))
            end
            ts, vs = f(v)
            types_buf = types_buf .. ts
            values_buf = values_buf .. vs
        end
        cmd_packet = cmd_packet .. null_map .. schar(0x01) .. types_buf .. values_buf
    end

    return self:_compose_packet(cmd_packet)
end

local function _query_resp(self, packet)
    local res, err, errno, sqlstate = self:read_result(packet)
    if not res then
        return false, sformat("%s[no:%s,sqlstate:%s]", err, errno, sqlstate)
    end
    if err ~= "again" then
        return true, res
    end
    local multiresultset = { res }
    while err == "again" do
        local mres, merr, merrno, msqlstate = self:read_result(packet)
        if not mres then
            return false, sformat("%s[no:%s,sqlstate:%s]", merr, merrno, msqlstate)
        end
        tinsert(multiresultset, mres)
    end
    multiresultset.multiresultset = true
    return true, multiresultset
end

local MysqlDB = class()
local prop = property(MysqlDB)
prop:reader("ip", nil)      --mysql地址
prop:reader("sock", nil)    --网络连接对象
prop:reader("name", "")     --dbname
prop:reader("port", 27017)  --mysql端口
prop:reader("user", "")     --user
prop:reader("passwd", "")   --passwd
prop:reader("packet_no", 0) --passwd
prop:reader("sessions", nil)                --sessions
prop:reader("server_ver", nil)              --server_ver
prop:reader("server_lang", nil)             --server_lang
prop:reader("server_status", nil)           --server_status
prop:reader("server_capabilities", nil)     --server_capabilities

prop:accessor("charset", "_default")        --charset
prop:accessor("compact_arrays", false)      --compact_arrays
prop:accessor("max_packet_size", 1024*1024) --max_packet_size,1mb

function MysqlDB:__init(conf)
    self.ip = conf.host
    self.name = conf.db
    self.port = conf.port
    self.user = conf.user
    self.passwd = conf.passwd
    self.sessions = QueueFIFO()
    --update
    timer_mgr:loop(PeriodTime.SECOND_MS * 2, function()
        self:update()
    end)
end

function MysqlDB:__release()
    self:close()
end

function MysqlDB:close()
    if self.sock then
        self.sessions:clear()
        self.sock:close()
        self.sock = nil
    end
end

function MysqlDB:update()
    if not self.sock then
        local sock = Socket(poll, self)
        if sock:connect(self.ip, self.port) then
            self.sock = sock
            local ok, err = self:auth()
            if not ok then
                log_err("[MysqlDB][update] auth db(%s:%s) failed! because: %s", self.ip, self.port, err)
                self.sock = nil
                return
            end
            log_info("[MysqlDB][update] connect db(%s:%s:%s) success!", self.ip, self.port, self.name)
        else
            log_err("[MysqlDB][update] connect db(%s:%s:%s) failed!", self.ip, self.port, self.name)
        end
    end
end

local function _parae_packet_type(buff)
    if not buff or #buff == 0 then
        return nil, "empty packet"
    end
    local typ = "DATA"
    local field_count = sbyte(buff, 1)
    if field_count == 0x00 then
        typ = "OK"
    elseif field_count == 0xff then
        typ = "ERR"
    elseif field_count == 0xfe then
        typ = "EOF"
    end
    return typ
end

local function _recv_auth_resp(self, packet)
    local typ, err = _parae_packet_type(packet)
    if not typ then
        return false, "failed to receive the result packet" .. err
    end
    if typ == "ERR" then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return false, sformat("errno:%d, msg:%s,sqlstate:%s", errno, msg, sqlstate)
    end
    if typ == "EOF" then
        return false, "old pre-4.1 authentication protocol not supported"
    end
    return true, packet
end

function MysqlDB:auth()
    local session_id = thread_mgr:build_session_id()
    self.sessions:push({ session_id, _recv_auth_resp })
    local ok, packet = thread_mgr:yield(session_id, "mysql_auth_wait", NetwkTime.DB_CALL_TIMEOUT)
    if not ok then
        return false, packet
    end
    --1 byte 协议版本号 (服务器认证报文开始)
    self.protocol_ver = sbyte(packet)
    --n byte 服务器版本号
    local server_ver, pos = _from_cstring(packet, 2)
    if not server_ver then
        return false, "bad handshake initialization packet: bad server version"
    end
    self.server_ver = server_ver
    --4 byte thread_id (未处理)
    pos = pos + 4
    --8 byte 挑战随机数1
    local scramble1 = ssub(packet, pos, pos + 8 - 1)
    if not scramble1 then
        return false, "1st part of scramble not found"
    end
    --1 byte 填充值 (未处理)
    pos = pos + 8 + 1
    --2 byte server_capabilities
    local server_capabilities, pos = _get_byte2(packet, pos)
    --1 byte server_lang
    self.server_lang = sbyte(packet, pos)
    --2 byte server_status
    self.server_status, pos = _get_byte2(packet, pos + 1)
    --2 byte server_capabilities high
    local more_capabilities, pos = _get_byte2(packet, pos)
    self.server_capabilities = server_capabilities | more_capabilities << 16
    --1 byte 挑战长度 (未使用) (未处理)
    --10 byte 填充值 (未处理)
    pos = pos + 1 + 10
    --12 byte 挑战随机数2
    local scramble2 = ssub(packet, pos, pos + 12 - 1)
    if not scramble2 then
        return false, "2nd part of scramble not found"
    end
    --1 byte 挑战数结束 (未处理) (服务器认证报文结束)
    --客户端认证报文
    --2 byte 客户端权能标志
    --2 byte 客户端权能标志扩展
    local client_flags = 260047
    --4 byte 最大消息长度
    local packet_size = self.max_packet_size
    --1 byte 字符编码
    local charset = schar(CHARSET_MAP[self.charset])
    --23 byte 填充值
    local fuller = srep("\0", 23)
    --n byte 用户名
    local user = self.user
    --n byte 挑战认证数据（scramble1+scramble2+passwd）
    local scramble = scramble1 .. scramble2
    local token = _compute_token(self.passwd, scramble)
    --n byte 数据库名（可选）
    local req = spack("<I4I4c1c23zs1z", client_flags, packet_size, charset, fuller, user, token, self.name)
    local authpacket = self:_compose_packet(req)
    return self:request(authpacket, _recv_auth_resp, "mysql_auth")
end

function MysqlDB:on_socket_close()
    log_err("[MysqlDB][on_socket_close] mysql server lost")
    self.sessions:clear()
    self.sock = nil
end

function MysqlDB:on_socket_recv(sock)
    while true do
        --mysql 响应报文结构
        local hdata = sock:peek(4)
        if not hdata then
            break
        end
        --3 byte消息长度
        local length, pos = _get_byte3(hdata, 1)
        --1 byte 消息序列号
        self.packet_no = sbyte(hdata, pos)
        --n byte 消息内容
        local bdata = nil
        if length > 0 then
            bdata = sock:peek(length, 4)
            if not bdata then
                break
            end
        end
        sock:pop(4 + length)
        --收到一个完整包
        local sessin_info = self.sessions:pop()
        if sessin_info then
            local session_id, mysql_response = tunpack(sessin_info)
            thread_mgr:response(session_id, mysql_response(self, bdata))
        end
    end
end

function MysqlDB:request(packet, mysql_response, quote)
    if not self.sock:send(packet) then
        return { badresult = true, errno = 30902, err = "send request failed" }
    end
    local session_id = thread_mgr:build_session_id()
    self.sessions:push({ session_id, mysql_response })
    return thread_mgr:yield(session_id, quote, NetwkTime.DB_CALL_TIMEOUT)
end

function MysqlDB:query(query)
    self.packet_no = -1
    local querypacket = self:_compose_packet(COM_QUERY .. query)
    return self:request(querypacket, _query_resp, "mysql_query")
end

local function _prepare_resp(self, packet, sql)
    local typ, err = _parae_packet_type(packet)
    if not typ then
        return false, {badresult = true, errno = 300101, err = err}
    end
    if typ == "ERR" then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return true, {badresult = true, errno = errno, err = msg, sqlstate = sqlstate}
    end
    --第一节只能是OK
    if typ ~= "OK" then
        return false, {badresult = true, errno = 300201, err = "first typ must be OK,now" .. typ }
    end
    local params, fields = {}, {}
    local prepare_id, field_count, param_count, warning_count = sunpack("<I4I2I2xI2", packet, 2)
    if param_count > 0 then
        local param = self:_recv_field_packet(packet)
        while param do
            tinsert(params, param)
            param = self:_recv_field_packet(packet)
        end
    end
    if field_count > 0 then
        local field = self:_recv_field_packet(packet)
        while field do
            tinsert(fields, field)
            field = self:_recv_field_packet(packet)
        end
    end
    return true, { params = params, fields = fields, prepare_id = prepare_id,
        field_count = field_count, param_count = param_count, warning_count = warning_count }
end

-- 注册预处理语句
function MysqlDB:prepare(sql)
    self.packet_no = -1
    local querypacket = self:_compose_packet(COM_STMT_PREPARE .. sql)
    return self:request(querypacket, _prepare_resp, "mysql_prepare")
end

local function _parse_row_data_binary(data, cols, compact)
    local ncols = #cols
    -- 空位图,前两个bit系统保留 (列数量 + 7 + 2) / 8
    local null_count = (ncols + 9) // 8
    local pos = 2 + null_count
    local value
    --空字段表
    local null_fields = {}
    local field_index = 1
    local byte
    for i = 2, pos - 1 do
        byte = sbyte(data, i)
        for j = 0, 7 do
            if field_index > 2 then
                if byte & (1 << j) == 0 then
                    null_fields[field_index - 2] = false
                else
                    null_fields[field_index - 2] = true
                end
            end
            field_index = field_index + 1
        end
    end
    local row = {}
    local parser
    for i = 1, ncols do
        local col = cols[i]
        local typ = col.type
        local name = col.name
        if not null_fields[i] then
            parser = _binary_parser[typ]
            if not parser then
                error("_parse_row_data_binary()error,unsupported field type " .. typ)
            end
            value, pos = parser(data, pos, col.is_signed)
            if compact then
                row[i] = value
            else
                row[name] = value
            end
        end
    end
    return row
end

local function _execute_resp(self, sock)
    local res, err, errno, sqlstate = self:read_execute_result(sock)
    if not res then
        local badresult = {}
        badresult.badresult = true
        badresult.err = err
        badresult.errno = errno
        badresult.sqlstate = sqlstate
        return true, badresult
    end
    if err ~= "again" then
        return true, res
    end
    local mulitresultset = {res}
    mulitresultset.mulitresultset = true
    local i = 2
    while err == "again" do
        res, err, errno, sqlstate = self:read_execute_result(sock)
        if not res then
            mulitresultset.badresult = true
            mulitresultset.err = err
            mulitresultset.errno = errno
            mulitresultset.sqlstate = sqlstate
            return true, mulitresultset
        end
        mulitresultset[i] = res
        i = i + 1
    end
    return true, mulitresultset
end

--[[
执行预处理语句
失败返回字段 errno, badresult, sqlstate, err
]]
function MysqlDB:execute(stmt, ...)
    self.packet_no = -1
    local querypacket, er = _compose_stmt_execute(self, stmt, CURSOR_TYPE_NO_CURSOR, {...})
    if not querypacket then
        return { badresult = true, errno = 30902, err = er }
    end
    return self:request(querypacket, _execute_resp, "mysql_execute")
end

--重置预处理句柄
function MysqlDB:stmt_reset(stmt)
    self.packet_no = -1
    local cmd_packet = spack("c1<I4", COM_STMT_RESET, stmt.prepare_id)
    local querypacket = self:_compose_packet(cmd_packet)
    return self:request(querypacket, _query_resp, "mysql_stmt_reset")
end

--关闭预处理句柄
function MysqlDB:stmt_close(stmt)
    self.packet_no = -1
    local cmd_packet = spack("c1<I4", COM_STMT_CLOSE, stmt.prepare_id)
    local querypacket = self:_compose_packet(cmd_packet)
    return self:request(querypacket, _query_resp, "mysql_stmt_close")
end

function MysqlDB:ping()
    self.packet_no = -1
    local querypacket, er = self:_compose_packet(COM_PING)
    if not querypacket then
        return { badresult = true, errno = 30902, err = er }
    end
    return self:request(querypacket, _query_resp, "mysql_ping")
end

function MysqlDB:read_result(packet)
    local typ, err = _parae_packet_type(packet)
    if not typ then
        return nil, err
    end
    if typ == "ERR" then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end
    if typ == "OK" then
        local res = _parse_ok_packet(packet)
        if res and res.server_status & SERVER_MORE_RESULTS_EXISTS ~= 0 then
            return res, "again"
        end
        return res
    end
    if typ ~= "DATA" then
        return nil, "packet type " .. typ .. " not supported"
    end
    -- typ == 'DATA'
    local field_count = _parse_result_set_header_packet(packet)
    local cols = {}
    for i = 1, field_count do
        local col, err, errno, sqlstate = self:_recv_field_packet(packet)
        if not col then
            return nil, err, errno, sqlstate
        end
        cols[i] = col
    end
    local typ, err = _parae_packet_type(packet)
    if not typ then
        return nil, err
    end
    if typ ~= "EOF" then
        return nil, "unexpected packet type " .. typ .. " while eof packet is " .. "expected"
    end
    -- typ == 'EOF'
    local compact = self.compact
    local rows = {}
    local i = 0
    while true do
        local typ, err = _parae_packet_type(packet)
        if not typ then
            return nil, err
        end
        if typ == "EOF" then
            local _, status_flags = _parse_eof_packet(packet)
            if status_flags & SERVER_MORE_RESULTS_EXISTS ~= 0 then
                return rows, "again"
            end
            break
        end
        -- typ == 'DATA'
        i = i + 1
        rows[i] = _parse_row_data_packet(packet, cols, compact)
    end
    return rows
end

function MysqlDB:read_execute_result(packet)
    local typ, err = _parae_packet_type(packet)
    if not typ then
        return nil, err
    end
    if typ == "ERR" then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end
    if typ == "OK" then
        local res = _parse_ok_packet(packet)
        if res and res.server_status & SERVER_MORE_RESULTS_EXISTS ~= 0 then
            return res, "again"
        end
        return res
    end
    if typ ~= "DATA" then
        return nil, "packet type " .. typ .. " not supported"
    end
    -- typ == 'DATA'
    local _, extra = _parse_result_set_header_packet(packet)
    local cols = {}
    local col
    while true do
        local typ, err = _parae_packet_type(packet)
        if typ == "EOF" then
            local warning_count, status_flags = _parse_eof_packet(packet)
            break
        end
        col = _parse_field_packet(packet)
        if not col then
            break
        end
        tinsert(cols, col)
    end
    --没有记录集返回
    if #cols < 1 then
        return {}
    end
    local compact = self.compact
    local rows = {}
    local row
    while true do
        local typ, err = _parae_packet_type(packet)
        if typ == "EOF" then
            local _, status_flags = _parse_eof_packet(packet)
            if status_flags & SERVER_MORE_RESULTS_EXISTS ~= 0 then
                return rows, "again"
            end
            break
        end
        row = _parse_row_data_binary(packet, cols, compact)
        if not col then
            break
        end
        tinsert(rows, row)
    end
    return rows
end

function MysqlDB:_compose_packet(req)
    --mysql 请求报文结构
    --3 byte 消息长度
    --1 byte 消息序列号，每次请求从0开始
    --n byte 消息内容
    local size = #req
    self.packet_no = self.packet_no + 1
    return spack("<I3Bc" .. size, size, self.packet_no, req)
end

function MysqlDB:_recv_field_packet(packet)
    local typ, err = _parae_packet_type(packet)
    if not typ then
        return nil, err
    end
    if typ == "ERR" then
        local errno, msg, sqlstate = _parse_err_packet(packet)
        return nil, msg, errno, sqlstate
    end
    if typ ~= "DATA" then
        return nil, "bad field packet type: " .. typ
    end
    -- typ == 'DATA'
    return _parse_field_packet(packet)
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
