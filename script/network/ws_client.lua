--ws_client.lua
local log_err           = logger.err
local log_info          = logger.info
local saddr             = qstring.addr
local jsoncodec         = json.jsoncodec
local wsscodec          = codec.wsscodec
local httpccodec        = codec.httpccodec
local make_timer        = quanta.make_timer
local derive_port       = luabus.derive_port

local proto_text        = luabus.eproto_type.text

local event_mgr         = quanta.get("event_mgr")
local socket_mgr        = quanta.get("socket_mgr")
local thread_mgr        = quanta.get("thread_mgr")

local SECOND_5_MS       = quanta.enum("PeriodTime", "SECOND_5_MS")
local CONNECT_TIMEOUT   = quanta.enum("NetwkTime", "CONNECT_TIMEOUT")

local WS_HEADERS        = {
    ["Upgrade"] = "websocket",
    ["Connection"] = "Upgrade",
    ["Sec-WebSocket-Version"] = "13",
    ["Sec-WebSocket-Key"] = "w4v7O6xFTi36lq3RNcgctw=="
}

local WSClient = class()
local prop = property(WSClient)
prop:reader("ip", nil)
prop:reader("host", nil)
prop:reader("token", nil)
prop:reader("timer", nil)
prop:reader("jcodec", nil)           --codec
prop:reader("wcodec", nil)           --codec
prop:reader("hcodec", nil)           --codec
prop:reader("alive", false)
prop:reader("session", nil)         --连接成功对象
prop:reader("port", 0)

function WSClient:__init(host)
    self.host = host
    self.timer = make_timer()
    self.jcodec = jsoncodec()
    self.wcodec = wsscodec(self.jcodec)
    self.hcodec = httpccodec(self.jcodec)
end

function WSClient:close()
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

function WSClient:connect(ws_addr)
    if self.session then
        if self.alive then
            return true
        end
        return false, "socket in connecting"
    end
    local ip, port = saddr(ws_addr)
    local real_port = derive_port(port)
    local session, cerr = socket_mgr.connect(ip, real_port, CONNECT_TIMEOUT, proto_text)
    if not session then
        log_err("[WSClient][connect] failed to connect: {}:{} err={}", ip, port, cerr)
        return false, cerr
    end
    --设置阻塞id
    local token = session.token
    local block_id = thread_mgr:build_session_id()
    session.on_connect = function(res)
        if res == "ok" then
            session.set_codec(self.hcodec)
            session.call_data("/", "GET", WS_HEADERS, "")
            return
        end
        self.token = nil
        self.session = nil
        thread_mgr:response(block_id, false, "connect failed")
    end
    session.on_call_data = function(recv_len, method, ...)
        if method == "WSS" then
            self:on_socket_recv(session, token, ...)
        else
            local ok, res = self:on_handshake(session, token, ...)
            thread_mgr:response(block_id, ok, res)
        end
    end
    session.on_error = function(stoken, err)
        self:on_socket_error(stoken, err)
    end
    self.token = token
    self.session = session
    self.ip, self.port = ip, port
    --阻塞模式挂起
    return thread_mgr:yield(block_id, "connect", CONNECT_TIMEOUT)
end

function WSClient:on_socket_error(token, err)
    self.host:on_socket_error(self, token, err)
    self.timer:unregister()
    self.alive = false
    self.session = nil
    self.token = nil
end

function WSClient:on_socket_recv(session, token, opcode, message)
    thread_mgr:fork(function()
        if opcode == 0x8 then -- close
            self:on_socket_error(token, "connection close")
            return
        end
        if opcode <= 0x02 then
            self.host:on_socket_recv(self, message)
        end
    end)
end

--握手协议
function WSClient:on_handshake(session, token, status, headers, body)
    if status ~= 101 then
        self.token = nil
        self.session = nil
        return false, body
    end
    self.alive = true
    event_mgr:fire_frame(function()
        session.set_codec(self.wcodec)
    end)
    self.host:on_socket_connect(session, token)
    --发送心跳
    self.timer:loop(SECOND_5_MS, function()
        self:send_data(0x9, "PING")
    end)
    log_info("[WSClient][on_handshake] handshake success {}", token)
    return true
end

function WSClient:send_data(...)
    if self.alive then
        local send_len = self.session.call_data(...)
        return send_len > 0
    end
    return false, "socket not alive"
end

--发送帧
function WSClient:send(data)
    return self:send_data(0x01, data)
end

return WSClient
