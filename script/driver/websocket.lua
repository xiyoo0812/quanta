--websocket.lua

local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local lsha1         = ssl.sha1
local lb64encode    = ssl.b64_encode
local jsoncodec     = json.jsoncodec
local wsscodec      = codec.wsscodec
local httpdcodec    = codec.httpdcodec
local qxpcall       = quanta.xpcall

local proto_text    = luabus.eproto_type.text

local event_mgr     = quanta.get("event_mgr")
local socket_mgr    = quanta.get("socket_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local NETWORK_TIMEOUT   = quanta.enum("NetwkTime", "NETWORK_TIMEOUT")

local WebSocket = class()
local prop = property(WebSocket)
prop:reader("ip", nil)
prop:reader("host", nil)
prop:reader("token", nil)
prop:reader("jcodec", nil)           --codec
prop:reader("wcodec", nil)           --codec
prop:reader("hcodec", nil)           --codec
prop:reader("alive", false)
prop:reader("session", nil)         --连接成功对象
prop:reader("listener", nil)
prop:reader("port", 0)

function WebSocket:__init(host)
    self.host = host
    self.jcodec = jsoncodec()
    self.wcodec = wsscodec(self.jcodec)
    self.hcodec = httpdcodec(self.jcodec)
end

function WebSocket:close()
    if self.session then
        if self.alive then
            self:send_data(0x8, "")
        end
        self.session.close()
        self.alive = false
        self.session = nil
        self.token = nil
    end
end

function WebSocket:listen(ip, port, ptype)
    if self.listener then
        return true
    end
    local listener = socket_mgr.listen(ip, port, proto_text)
    if not listener then
        log_err("[WebSocket][listen] failed to listen: {}:{}", ip, port)
        return false
    end
    listener.set_codec(self.hcodec)
    log_info("[WebSocket][listen] start listen at: {}:{}", ip, port)
    listener.on_accept = function(session)
        qxpcall(self.on_socket_accept, "on_socket_accept: {}", self, session, ip, port)
    end
    self.ip, self.port = ip, port
    self.listener = listener
    return true
end

function WebSocket:on_socket_accept(session)
    local socket = WebSocket(self.host)
    socket:accept(session, session.ip, self.port)
end

function WebSocket:on_socket_error(token, err)
    thread_mgr:fork(function()
        if self.session then
            self.token = nil
            self.session = nil
            self.alive = false
            log_err("[WebSocket][on_socket_error] err: {} - {}!", err, token)
            self.host:on_socket_error(self, token, err)
        end
    end)
end

function WebSocket:on_socket_recv(session, token, opcode, message)
    thread_mgr:fork(function()
        if opcode == 0x8 then -- close/error
            self:close()
            self.host:on_socket_error(self, token, message)
            return
        end
        if opcode == 0x9 then --Ping
            self:send_frame(0xA, "PONG")
            return
        end
        if opcode <= 0x02 then
            self.host:on_socket_recv(self, token, message)
        end
    end)
end

--accept
function WebSocket:accept(session, ip, port)
    local token = session.token
    session.set_timeout(NETWORK_TIMEOUT)
    session.on_call_data = function(recv_len, method, ...)
        if method == "WSS" then
            self:on_socket_recv(session, token, ...)
        else
            self:on_handshake(session, token, ...)
        end
    end
    session.on_error = function(stoken, err)
        self:on_socket_error(stoken, err)
    end
    self.ip, self.port = ip, port
end

--握手协议
function WebSocket:on_handshake(session, token, url, params, headers, body)
    log_debug("[WebSocket][on_handshake] recv: {}, {}, {}, {}!", url, params, headers, body)
    local upgrade = headers["Upgrade"]
    if not upgrade or upgrade ~= "websocket" then
        return self:send_data(400, nil, "can upgrade only to websocket!")
    end
    local connection = headers["Connection"]
    if not connection or connection ~= "Upgrade" then
        return self:send_data(400, nil, "connection must be upgrade!")
    end
    local version = headers["Sec-WebSocket-Version"]
    if not version or version ~= "13" then
        return self:send_data(400, nil, "Upgrade Required Sec-WebSocket-Version: 13")
    end
    local key = headers["Sec-WebSocket-Key"]
    if not key then
        return self:send_data(400, nil, "Sec-WebSocket-Key must not be nil!")
    end
    local cbheaders = {
        ["Upgrade"] = "websocket",
        ["Connection"] = "Upgrade",
        ["Sec-WebSocket-Accept"] = lb64encode(lsha1(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
    }
    if headers["Sec-WebSocket-Protocol"] then
        cbheaders["Sec-WebSocket-Protocol"] = "mqtt"
    end
    self.alive = true
    --handshake 完成
    self.token = token
    self.session = session
    self:send_data(101, cbheaders, "")
    self.host:on_socket_accept(self, token)
    event_mgr:fire_frame(function()
        session.set_codec(self.wcodec)
    end)
    return true
end

function WebSocket:send_data(...)
    if self.alive then
        local send_len = self.session.call_data(...)
        return send_len > 0
    end
    return false, "socket not alive"
end

--发送帧
function WebSocket:send_frame(data)
    return self:send_data(0x01, data)
end

return WebSocket
