--socket.lua

local log_err           = logger.err
local log_info          = logger.info
local qxpcall           = quanta.xpcall

local proto_text        = luabus.eproto_type.text

local socket_mgr        = quanta.get("socket_mgr")
local thread_mgr        = quanta.get("thread_mgr")

local CONNECT_TIMEOUT   = quanta.enum("NetwkTime", "CONNECT_TIMEOUT")
local NETWORK_TIMEOUT   = quanta.enum("NetwkTime", "NETWORK_TIMEOUT")

local Socket = class()
local prop = property(Socket)
prop:reader("ip", nil)
prop:reader("port", 0)
prop:reader("host", nil)
prop:reader("codec", nil)
prop:reader("token", nil)
prop:reader("alive", false)
prop:reader("session", nil)          --连接成功对象
prop:reader("listener", nil)
prop:accessor("id", 0)

function Socket:__init(host, ip, port)
    self.host = host
    self.port = port
    self.ip = ip
end

function Socket:close()
    if self.session then
        self.session.close()
        self.alive = false
        self.session = nil
        self.codec = nil
        self.token = nil
    end
    if self.listener then
        self.listener.close()
        self.listener = nil
        self.codec = nil
    end
end

function Socket:listen(ip, port)
    if self.listener then
        return true
    end
    self.listener = socket_mgr.listen(ip, port, proto_text)
    if not self.listener then
        log_err("[Socket][listen] failed to listen: {}:{}", ip, port)
        return false
    end
    self.ip, self.port = ip, port
    log_info("[Socket][listen] start listen at: {}:{}", ip, port)
    self.listener.on_accept = function(session)
        qxpcall(self.on_socket_accept, "on_socket_accept: {}", self, session, ip, port)
    end
    return true
end

function Socket:set_codec(codec)
    if self.session then
        self.codec = codec
        self.session.set_codec(codec)
    end
    if self.listener then
        self.codec = codec
        self.listener.set_codec(codec)
    end
end

function Socket:connect(ip, port)
    if self.session then
        if self.alive then
            return true
        end
        return false, "socket in connecting"
    end
    local session, cerr = socket_mgr.connect(ip, port, CONNECT_TIMEOUT, proto_text)
    if not session then
        log_err("[Socket][connect] failed to connect: {}:{} err={}", ip, port, cerr)
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
        thread_mgr:response(block_id, success, res)
    end
    session.on_call_data = function(recv_len, ...)
        self:on_socket_recv(token, ...)
    end
    session.on_error = function(stoken, err)
        self:on_socket_error(stoken, err)
    end
    self.token = token
    self.session = session
    self.ip, self.port = ip, port
    --阻塞挂起
    local ok, res = thread_mgr:yield(block_id, "connect", CONNECT_TIMEOUT)
    if not ok then
        --处理超时
        self:close()
    end
    return ok, res
end

function Socket:on_socket_accept(session)
    local socket = Socket(self.host)
    socket:accept(session, session.ip, self.port)
end

function Socket:on_socket_recv(token, ...)
    thread_mgr:fork(function(...)
        self.host:on_socket_recv(self, ...)
    end, ...)
end

function Socket:on_socket_error(token, err)
    thread_mgr:fork(function()
        if self.session then
            self.codec = nil
            self.token = nil
            self.session = nil
            self.alive = false
            log_err("[Socket][on_socket_error] err: {} - {}!", err, token)
            self.host:on_socket_error(self, token, err)
        end
    end)
end

function Socket:accept(session, ip, port)
    local token = session.token
    session.set_timeout(NETWORK_TIMEOUT)
    session.on_call_data = function(recv_len, ...)
        self:on_socket_recv(token, ...)
    end
    session.on_error = function(stoken, err)
        self:on_socket_error(stoken, err)
    end
    self.alive = true
    self.token = token
    self.session = session
    self.ip, self.port = ip, port
    self.host:on_socket_accept(self, token)
end

function Socket:send_data(...)
    if self.alive then
        local send_len = self.session.call_data(...)
        return send_len > 0
    end
    return false, "socket not alive"
end

return Socket
