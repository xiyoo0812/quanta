--ws_server.lua
local log_err           = logger.err
local log_info          = logger.info
local lsha1             = ssl.sha1
local lb64encode        = ssl.b64_encode
local jsoncodec         = json.jsoncodec
local wsscodec          = codec.wsscodec
local httpdcodec        = codec.httpdcodec
local qxpcall           = quanta.xpcall
local signalquit        = signal.quit
local derive_port       = luabus.derive_port

local PROTO_TEXT        = luabus.eproto_type.TEXT

local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local socket_mgr        = quanta.get("socket_mgr")
local thread_mgr        = quanta.get("thread_mgr")

local NETWORK_TIMEOUT   = quanta.enum("NetwkTime", "NETWORK_TIMEOUT")

local WSServer = class()
local prop = property(WSServer)
prop:reader("ip", nil)
prop:reader("port", 8191)
prop:reader("jcodec", nil)          --codec
prop:reader("wcodec", nil)          --codec
prop:reader("hcodec", nil)          --codec
prop:reader("alive", false)
prop:reader("listener", nil)
prop:reader("sessions", {})         --sessions

function WSServer:__init()
    self.jcodec = jsoncodec()
    self.hcodec = httpdcodec()
    self.wcodec = wsscodec(self.jcodec)
    --注册退出
    update_mgr:attach_quit(self)
end

function WSServer:on_quit()
    if self.listener then
        self.listener.close()
        self.listener = nil
        self.wcodec = nil
        self.hcodec = nil
        self.jcodec = nil
        log_info("[WSServer][on_quit]")
    end
end

function WSServer:listen(ip, port, induce)
    if not ip or not port then
        log_err("[WSServer][listen] ip:{} or port:{} is nil", ip, port)
        signalquit()
        return
    end
    local induce_port = induce and (port + quanta.order - 1) or port
    local real_port = derive_port(induce_port, ip)
    local listener = socket_mgr.listen(ip, real_port, PROTO_TEXT)
    if not listener then
        log_err("[WSServer][listen] failed to listen: {}:{}", ip, real_port)
        signalquit(1)
        return
    end
    listener.on_accept = function(session)
        qxpcall(self.on_socket_accept, "on_socket_accept: {}", self, session)
    end
    log_info("[WSServer][listen] start listen at: {}:{}", ip, real_port)
    self.ip, self.port = ip, port
    self.listener = listener
end

-- 连接回调
function WSServer:on_socket_accept(session)
    local token = session.token
    session.set_codec(self.hcodec)
    -- 设置超时(心跳)
    session.set_timeout(NETWORK_TIMEOUT)
    -- 设置回调
    session.on_call_data = function(recv_len, ...)
        thread_mgr:fork(self.on_socket_recv, nil, self, session, token, ...)
    end
    session.on_error = function(stoken, err)
        thread_mgr:fork(self.on_socket_error, nil, self, stoken, err)
    end
    --通知链接成功
    event_mgr:notify_listener("on_socket_accept", session)
end

function WSServer:on_socket_error(token, err)
    local session = self:remove_session(token)
    if session then
        event_mgr:notify_listener("on_socket_error", session, token, err)
    end
end

function WSServer:on_socket_recv(socket, token, ...)
    if socket.handshake then
        return self:on_wss_recv(socket, token, ...)
    end
    self:on_handshake(socket, token, ...)
end

--回调
function WSServer:on_wss_recv(socket, token, opcode, message)
    if opcode == 0x8 then -- close
        self:on_socket_error(token, "connection close")
        return
    end
    if opcode == 0x9 then --Ping
        socket.call_data(0xA, "PONG")
        return
    end
    if opcode <= 0x02 then
        event_mgr:notify_listener("on_socket_cmd", socket, message)
    end
end

--握手协议
function WSServer:on_handshake(socket, token, method, url, params, headers, body)
    local upgrade = headers["Upgrade"]
    if not upgrade or upgrade ~= "websocket" then
        log_err("[WSServer][on_handshake] handshake failed: can upgrade only to websocket")
        return socket.call_data(400, nil, "can upgrade only to websocket!")
    end
    local connection = headers["Connection"]
    if not connection or connection ~= "Upgrade" then
        log_err("[WSServer][on_handshake] handshake failed: connection must be upgrade")
        return socket.call_data(400, nil, "connection must be upgrade!")
    end
    local version = headers["Sec-WebSocket-Version"]
    if not version or version ~= "13" then
        log_err("[WSServer][on_handshake] handshake failed: Upgrade Required Sec-WebSocket-Version: 13")
        return socket.call_data(400, nil, "Upgrade Required Sec-WebSocket-Version: 13")
    end
    local key = headers["Sec-WebSocket-Key"]
    if not key then
        log_err("[WSServer][on_handshake] handshake failed: Sec-WebSocket-Key must not be nil")
        return socket.call_data(400, nil, "Sec-WebSocket-Key must not be nil!")
    end
    local cbheaders = {
        ["Upgrade"] = "websocket",
        ["Connection"] = "Upgrade",
        ["Sec-WebSocket-Accept"] = lb64encode(lsha1(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
    }
    if headers["Sec-WebSocket-Protocol"] then
        cbheaders["Sec-WebSocket-Protocol"] = "mqtt"
    end
    socket.call_data(101, cbheaders, "")
    --handshake 完成
    socket.handshake = true
    event_mgr:fire_frame(function()
        socket.set_codec(self.wcodec)
    end)
    self:add_session(socket)
    log_info("[WSServer][on_handshake] handshake success {}", token)
    return true
end

function WSServer:write(session, data)
    if session.token == 0 then
        log_err("[WSServer][write] session lost! data:({})", data)
        return false
    end
    return session.call_data(0x01, data)
end

-- 发送数据
function WSServer:send(session, data)
    return self:write(session, data)
end

-- 关闭会话
function WSServer:close_session(session)
    if self:remove_session(session.token) then
        session.close()
    end
end

-- 关闭会话
function WSServer:close_session_by_token(token)
    local session = self.sessions[token]
    if session then
        self:remove_session(token)
        session.close()
    end
end

-- 添加会话
function WSServer:add_session(session)
    local token = session.token
    if not self.sessions[token] then
        self.sessions[token] = session
    end
    return token
end

-- 移除会话
function WSServer:remove_session(token)
    local session = self.sessions[token]
    if session then
        self.sessions[token] = nil
        return session
    end
end

-- 查询会话
function WSServer:get_session_by_token(token)
    return self.sessions[token]
end

return WSServer
