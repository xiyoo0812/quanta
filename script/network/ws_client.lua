--ws_client.lua
local log_err           = logger.err
local log_info          = logger.info
local saddr             = qstring.addr
local jsoncodec         = json.jsoncodec
local lnext_id          = luakit.next_id
local wsscodec          = codec.wsscodec
local httpccodec        = codec.httpccodec
local make_timer        = quanta.make_timer

local PROTO_TEXT        = luabus.eproto_type.TEXT

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
prop:reader("port", 0)
prop:reader("host", nil)
prop:reader("token", nil)
prop:reader("timer", nil)
prop:reader("jcodec", nil)           --codec
prop:reader("wcodec", nil)           --codec
prop:reader("hcodec", nil)           --codec
prop:reader("alive", false)
prop:reader("session", nil)         --连接成功对象
prop:reader("handshake", false)

function WSClient:__init(host)
    self.host = host
    self.timer = make_timer()
    self.jcodec = jsoncodec()
    self.hcodec = httpccodec()
    self.wcodec = wsscodec(self.jcodec, true)
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
    local session, cerr = socket_mgr.connect(ip, port, CONNECT_TIMEOUT, PROTO_TEXT)
    if not session then
        log_err("[WSClient][connect] failed to connect: {}:{} err={}", ip, port, cerr)
        return false, cerr
    end
    --设置阻塞id
    local token = session.token
    local block_id = lnext_id()
    session.on_connect = function(res)
        local success = res == "ok"
        if not success then
            self.token = nil
            self.session = nil
        end
        thread_mgr:response(block_id, success, res)
    end
    self:init_session(session, token, ip, port)
    --阻塞挂起
    local ok, res = thread_mgr:yield(block_id, "connect", CONNECT_TIMEOUT)
    if not ok then
        self:close()
        return ok, res
    end
    WS_HEADERS["Host"] = ip
    log_info("[Socket][connect] connect success!")
    return self:on_socket_connected(session, token)
end

function WSClient:on_socket_connected(session, token)
    local session_id = lnext_id()
    session.set_codec(self.hcodec)
    session.call_data(session_id, "/", "GET", WS_HEADERS, "")
    local ok, res = thread_mgr:yield(session_id, "handshake", CONNECT_TIMEOUT)
    log_info("[WSClient][on_socket_connected] success {}:{}-{}", token, ok, res)
    if not ok then
        self:close()
        return ok, res
    end
    self.alive = true
    self.handshake = true
    event_mgr:fire_frame(function()
        session.set_codec(self.wcodec)
    end)
    self.host:on_socket_connect(session, token)
    log_info("[WSClient][on_socket_connected] handshake success {}:{}", token, session_id)
    --发送心跳
    self.timer:loop(SECOND_5_MS, function()
        self:send_data(0x9, "PING")
    end)
    return ok
end

function WSClient:init_session(session, token, ip, port)
    self.token = token
    self.session = session
    self.ip, self.port = ip, port
    session.on_call_data = function(recv_len, ...)
        thread_mgr:fork(self.on_socket_recv, nil, self, ...)
    end
    session.on_error = function(stoken, err)
        thread_mgr:fork(self.on_socket_error, nil, self, stoken, err)
    end
end

function WSClient:on_socket_error(token, err)
    self.host:on_socket_error(self, token, err)
    self.timer:unregister()
    self.alive = false
    self.session = nil
    self.token = nil
end

function WSClient:on_socket_recv(...)
    if self.handshake then
        self:on_wss_recv(...)
        return
    end
    self:on_handshake(...)
end

function WSClient:on_wss_recv(opcode, message)
    if opcode == 0x8 then -- close
        self:on_socket_error(self.token, "connection close")
        return
    end
    if opcode <= 0x02 then
        self.host:on_socket_recv(self, message)
    end
end

--握手协议
function WSClient:on_handshake(session_id, status, headers, body)
    thread_mgr:response(session_id, status == 101, body, headers)
end

function WSClient:send_data(opcode, data)
    if self.alive then
        local send_len = self.session.call_data(opcode, data)
        return send_len > 0
    end
    return false, "socket not alive"
end

--发送帧
function WSClient:send(data, opcode)
    return self:send_data(opcode or 0x01, data)
end

return WSClient
