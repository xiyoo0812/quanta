--socket.lua
local lbus          = require("luabus")

local ssub          = string.sub
local log_err       = logger.err
local log_warn      = logger.warn
local log_info      = logger.info
local ends_with     = qstring.ends_with
local split_pos     = qstring.split_pos
local qxpcall       = quanta.xpcall

local eproto_type   = lbus.eproto_type

local socket_mgr        = quanta.get("socket_mgr")
local thread_mgr        = quanta.get("thread_mgr")

local WARNING_BYTES     = environ.number("QUANTA_WARNING_BYTES")

local CONNECT_TIMEOUT   = quanta.enum("NetwkTime", "CONNECT_TIMEOUT")
local NETWORK_TIMEOUT   = quanta.enum("NetwkTime", "NETWORK_TIMEOUT")

local Socket = class()
local prop = property(Socket)
prop:reader("ip", nil)
prop:reader("port", 0)
prop:reader("host", nil)
prop:reader("token", nil)
prop:reader("alive", false)
prop:reader("alive_time", 0)
prop:reader("proto_type", eproto_type.text)
prop:reader("session", nil)          --连接成功对象
prop:reader("listener", nil)
prop:reader("recvbuf", "")

function Socket:__init(host, ip, port)
    self.host = host
    self.port = port
    self.ip = ip
end

function Socket:__release()
    self:close()
end

function Socket:close()
    if self.session then
        self.session.close()
        self.alive = false
        self.session = nil
        self.token = nil
    end
end

function Socket:listen(ip, port, ptype)
    if self.listener then
        return true
    end
    if ptype then
        self.proto_type = ptype
    end
    self.listener = socket_mgr.listen(ip, port, self.proto_type)
    if not self.listener then
        log_err("[Socket][listen] failed to listen: %s:%d type=%d", ip, port, self.proto_type)
        return false
    end
    self.ip, self.port = ip, port
    log_info("[Socket][listen] start listen at: %s:%d type=%d", ip, port, self.proto_type)
    self.listener.on_accept = function(session)
        qxpcall(self.on_socket_accept, "on_socket_accept: %s", self, session, ip, port)
    end
    return true
end

function Socket:connect(ip, port, ptype)
    if self.session then
        if self.alive then
            return true
        end
        return false, "socket in connecting"
    end
    if ptype then
        self.proto_type = ptype
    end
    local session, cerr = socket_mgr.connect(ip, port, CONNECT_TIMEOUT, self.proto_type)
    if not session then
        log_err("[Socket][connect] failed to connect: %s:%d type=%d, err=%s", ip, port, self.proto_type, cerr)
        return false, cerr
    end
    --设置阻塞id
    local token = session.token
    local block_id = thread_mgr:build_session_id()
    session.on_connect = function(res)
        local success = res == "ok"
        self.alive = success
        if not success then
            self.token = nil
            self.session = nil
        end
        self.alive_time = quanta.now
        thread_mgr:response(block_id, success, res)
    end
    session.on_call_text = function(recv_len, slice)
        qxpcall(self.on_socket_recv, "on_socket_recv: %s", self, token, slice)
    end
    session.on_call_common = function(recv_len, slice)
        qxpcall(self.on_socket_recv, "on_socket_recv: %s", self, token, slice)
    end
    session.on_error = function(stoken, err)
        thread_mgr:fork(function()
            self:on_socket_error(stoken, err)
        end)
    end
    self.token = token
    self.session = session
    self.ip, self.port = ip, port
    --阻塞模式挂起
    return thread_mgr:yield(block_id, "connect", CONNECT_TIMEOUT)
end

function Socket:on_socket_accept(session)
    local socket = Socket(self.host)
    socket:accept(session, session.ip, self.port)
end

function Socket:on_socket_recv(token, slice)
    local more_byte = socket_mgr:get_recvbuf_size(token)
    if more_byte > WARNING_BYTES then
        log_warn("[Socket][on_socket_recv] socket %s recv buf has so more (%s) bytes!", token, more_byte)
    end
    self.alive_time = quanta.now
    if self.proto_type == eproto_type.text then
        self.recvbuf = self.recvbuf .. slice.string()
        self.host:on_socket_recv(self, self.token)
    else
        self.host:on_slice_recv(self, slice, self.token)
    end
end

function Socket:on_socket_error(token, err)
    if self.session then
        self.session = nil
        self.alive = false
        log_err("[Socket][on_socket_error] err: %s - %s!", err, token)
        self.host:on_socket_error(self, token, err)
        self.token = nil
    end
end

function Socket:accept(session, ip, port)
    local token = session.token
    session.set_timeout(NETWORK_TIMEOUT)
    session.on_call_text = function(recv_len, slice)
        qxpcall(self.on_socket_recv, "on_socket_recv: %s", self, token, slice)
    end
    session.on_error = function(stoken, err)
        thread_mgr:fork(function()
            self:on_socket_error(stoken, err)
        end)
    end
    self.alive = true
    self.token = token
    self.session = session
    self.ip, self.port = ip, port
    self.host:on_socket_accept(self, token)
end

function Socket:peek(len, offset)
    offset = offset or 0
    if offset + len <= #self.recvbuf then
        return ssub(self.recvbuf, offset + 1, offset + len)
    end
end

function Socket:peek_lines(split_char)
    if #self.recvbuf >= #split_char then
        if ends_with(self.recvbuf, split_char) then
            return split_pos(self.recvbuf, split_char)
        end
    end
end

function Socket:pop(len)
    if len > 0 then
        if #self.recvbuf > len then
            self.recvbuf = ssub(self.recvbuf, len + 1)
        else
            self.recvbuf = ""
        end
    end
end

function Socket:send(data)
    if self.alive and data then
        local send_len = self.session.call_text(data, #data)
        return self:on_send(self.session.token, send_len)
    end
    return false, "socket not alive"
end

function Socket:send_slice(slice)
    if self.alive and slice then
        local send_len = self.session.call_slice(slice)
        return self:on_send(self.session.token, send_len)
    end
    return false, "socket not alive"
end

--调用rpc后续处理
function Socket:on_send(token, send_len)
    if send_len > 0 then
        local more_byte = socket_mgr:get_sendbuf_size(token)
        if more_byte > WARNING_BYTES then
            log_warn("[Socket][on_send] socket %s send buf has so more (%s) bytes!", token, more_byte)
        end
        return true
    end
    return false
end

return Socket
