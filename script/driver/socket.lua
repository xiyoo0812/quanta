--socket.lua
local ssub          = string.sub
local sfind         = string.find
local log_err       = logger.err
local log_info      = logger.info
local qxpcall       = quanta.xpcall

local NetwkTime     = enum("NetwkTime")
local PeriodTime    = enum("PeriodTime")

local timer_mgr     = quanta.get("timer_mgr")
local socket_mgr    = quanta.get("socket_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local Socket = class()
local prop = property(Socket)
prop:reader("ip", nil)
prop:reader("fd", nil)
prop:reader("host", nil)
prop:reader("session", nil)          --连接成功对象
prop:reader("listener", nil)
prop:reader("recvbuf", "")
prop:reader("port", 0)

function Socket:__init(host)
    self.host = host
end

function Socket:__release()
    self:close()
end

function Socket:close()
    if self.session then
        timer_mgr:once(PeriodTime.FRAME_MS, function()
            self.session.close()
            self.session = nil
        end)
    end
end

function Socket:is_alive()
    return self.session ~= nil
end

function Socket:listen(ip, port)
    if self.listener then
        return true
    end
    local proto_type = 2
    self.listener = socket_mgr.listen(ip, port, proto_type)
    if not self.listener then
        log_err("[Socket][listen] failed to listen: %s:%d type=%d", ip, port, proto_type)
        return false
    end
    self.ip, self.port = ip, port
    log_info("[Socket][listen] start listen at: %s:%d type=%d", ip, port, proto_type)
    self.listener.on_accept = function(session)
        qxpcall(self.on_session_accept, "on_session_accept: %s", self, session)
    end
    return true
end

function Socket:connect(ip, port)
    if self.session then
        return true
    end
    local proto_type = 2
    local session, cerr = socket_mgr.connect(ip, port, NetwkTime.CONNECT_TIMEOUT, proto_type)
    if not session then
        log_err("[Socket][connect] failed to connect: %s:%d type=%d, err=%s", ip, port, proto_type, cerr)
        return false, cerr
    end
    --设置阻塞id
    local block_id = thread_mgr:build_session_id()
    session.on_connect = function(res)
        local success = res == "ok"
        if not success then
            self:on_socket_error(socket, res)
        end
        thread_mgr:response(block_id, success, res)
    end
    session.on_call_text = function(recv_len, data)
        qxpcall(self.on_socket_recv, "on_socket_recv: %s", self, session, data)
    end
    session.on_error = function(err)
        thread_mgr:fork(function()
            self:on_socket_error(session, err)
        end)
    end
    self.session = session
    self.fd = session.token
    self.ip, self.port = ip, port
    --阻塞模式挂起
    return thread_mgr:yield(block_id, "connect", NetwkTime.CONNECT_TIMEOUT)
end

function Socket:on_session_accept(session)
    local socket = Socket(self.host)
    socket:accept(session, session.ip, self.port)
end

function Socket:on_socket_recv(session, data)
    self.recvbuf = self.recvbuf .. data
    if #self.recvbuf > 0 then
        self.host:on_socket_recv(self, self.fd)
    end
end

function Socket:on_socket_error(session, err)
    if self.session then
        self.session = nil
        log_err("[Socket][on_socket_error] err: %s - %s!", err, self.fd)
        self.host:on_socket_error(self, self.fd, err)
    end
end

function Socket:accept(session, ip, port)
    session.set_timeout(NetwkTime.NETWORK_TIMEOUT)
    session.on_call_text = function(recv_len, data)
        qxpcall(self.on_socket_recv, "on_socket_recv: %s", self, session, data)
    end
    session.on_error = function(err)
        thread_mgr:fork(function()
            self:on_socket_error(session, err)
        end)
    end
    self.session = session
    self.fd = session.token
    self.ip, self.port = ip, port
    self.host:on_socket_accept(self, self.fd)
end

function Socket:peek(len, offset)
    offset = offset or 0
    if offset + len <= #self.recvbuf then
        return ssub(self.recvbuf, offset + 1, offset + len)
    end
end

function Socket:peek_line(line_flag, offset)
    offset = offset or 0
    local i, j = sfind(self.recvbuf, line_flag, offset + 1)
    if i then
        return ssub(self.recvbuf, 1, i - 1), j
    end
end

function Socket:pop(len)
    if #self.recvbuf > len then
        self.recvbuf = ssub(self.recvbuf, len + 1)
    else
        self.recvbuf = ""
    end
end

function Socket:send(data)
    if (not self.session) or (not data) then
        return false
    end
    local send_len = self.session.call_text(data)
	return send_len > 0
end

return Socket
