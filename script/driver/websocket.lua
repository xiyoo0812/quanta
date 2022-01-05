--websocket.lua
local lhttp         = require("lhttp")
local lcrypt        = require("lcrypt")
local ljson         = require("lcjson")

local ssub          = string.sub
local sfind         = string.find
local spack         = string.pack
local sunpack       = string.unpack
local log_err       = logger.err
local log_info      = logger.info
local lsha1         = lcrypt.sha1
local lb64encode    = lcrypt.b64_encode
local qxpcall       = quanta.xpcall

local type          = type
local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local json_encode   = ljson.encode
local tunpack       = table.unpack

local socket_mgr    = quanta.get("socket_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local WebSocket = class()
local prop = property(WebSocket)
prop:reader("ip", nil)
prop:reader("host", nil)
prop:reader("token", nil)
prop:reader("alive", false)
prop:reader("alive_time", 0)
prop:reader("session", nil)         --连接成功对象
prop:reader("listener", nil)
prop:reader("recvbuf", "")
prop:reader("context", nil)         --context
prop:reader("port", 0)

local function _async_call(quote, callback)
    local session_id = thread_mgr:build_session_id()
    self.context = { callback = callback, session_id = session_id }
    return thread_mgr:yield(session_id, quote, DB_TIMEOUT)
end

function WebSocket:__init(host)
    self.host = host
end

function WebSocket:close()
    if self.session then
        if self.alive then
            self:send_frame(true, 0x8, "")
        end
        self.session.close()
        self.context = nil
        self.alive = false
        self.session = nil
        self.token = nil
    end
end

function WebSocket:listen(ip, port)
    if self.listener then
        return true
    end
    local proto_type = 2
    self.listener = socket_mgr.listen(ip, port, proto_type)
    if not self.listener then
        log_err("[WebSocket][listen] failed to listen: %s:%d type=%d", ip, port, proto_type)
        return false
    end
    self.ip, self.port = ip, port
    log_info("[WebSocket][listen] start listen at: %s:%d type=%d", ip, port, proto_type)
    self.listener.on_accept = function(session)
        qxpcall(self.on_socket_accept, "on_socket_accept: %s", self, session, ip, port)
    end
    return true
end

function WebSocket:on_socket_accept(session)
    local socket = WebSocket(self.host)
    socket:accept(session, session.ip, self.port)
end

function WebSocket:on_socket_recv(session, data)
    self.recvbuf = self.recvbuf .. data
    self.alive_time = quanta.now
    local token = session.token
    if self.alive then
        while true do
            thread_mgr:fork(function()
                local context = self.context
                if not context then
                    local ok, message = self:recv_frame()
                    if not ok then
                        log_err("[WebSocket][on_socket_recv] recv_frame failed: %s", message)
                        self:close()
                        return
                    end
                    if not message then
                        break
                    end
                    self.context = nil
                    self.host:on_socket_recv(self, message)
                else
                    thread_mgr:response(context.session_id, conteext.callback(self))
                end
            end)
        end
    else
        if self:on_accept_connect(session, token) then
            self.alive = true
            self.token = token
            self.session = session
            self.host:on_socket_accept(self, token)
        end
    end
end

function WebSocket:on_socket_error(token, err)
    if self.session then
        self.session = nil
        self.alive = false
        log_err("[WebSocket][on_socket_error] err: %s - %s!", err, token)
        self.host:on_socket_error(self, token, err)
        self.token = nil
    end
end

function WebSocket:accept(session, ip, port)
    self.ip, self.port = ip, port
    session.set_timeout(NetwkTime.NETWORK_TIMEOUT)
    session.on_call_text = function(recv_len, data)
        qxpcall(self.on_socket_recv, "on_socket_recv: %s", self, session, data)
    end
    session.on_error = function(token, err)
        thread_mgr:fork(function()
            self:on_socket_error(token, err)
        end)
    end
end

function WebSocket:on_accept_connect(session, token)
    local request = lhttp.create_request()
    if not request then
        log_debug("[WebSocket][on_accept_connect] create_request(token:%s)!", token)
        session.close()
        return
    end
    if not request:append(self.recvbuf) then
        log_err("[WebSocket][on_accept_connect] http request append failed, close client(token:%s)!", token)
        return self:response(400, request, "this http request parse error!")
    end
    self.recvbuf = ""
    request:process()
    local state = request:state()
    local HTTP_REQUEST_ERROR = 2
    if state == HTTP_REQUEST_ERROR then
        log_err("[WebSocket][on_accept_connect] http request process failed, close client(token:%s)!", token)
        return self:response(400, request, "this http request parse error!") 
    end
    local headers = request:headers()
    local upgrade = headers["upgrade"]
    if not upgrade or upgrade:lower() ~= "websocket" then
        return self:response(400, request, "can upgrade only to websocket!")
    end
    local connection = headers["connection"]
    if not connection or not connection:lower():find("upgrade", 1, true) then
        return self:response(400, request, "connection must be upgrade!")
    end
    local version = headers["sec-websocket-version"]
    if not version or version ~= "13" then
        return self:response(400, request, "HTTP/1.1 Upgrade Required\r\nSec-WebSocket-Version: 13\r\n\r\n")
    end
    local key = headers["sec-websocket-key"]
    if not key then
        return self:response(400, request, "Sec-WebSocket-Key must not be nil!")
    end
    local protocol = headers["sec-websocket-protocol"] 
    if protocol then
        local i = protocol:find(",", 1, true)
        protocol = sformat("Sec-WebSocket-Protocol: %s\r\n", protocol:sub(1, i and i-1))
    end
    local accept = lb64encode(lsha1(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
    local fmt_text = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n%s\r\n"
    self:send(sformat(fmt_text, accept, protocol or ""))
    return true
end

function WebSocket:response(status, request, response)
    local text = request:response(status, "text/plain", response or "")
    self:send(text)
    self:close()
end

function WebSocket:pop(len)
    if len <= 0 then
        return
    end
    if #self.recvbuf > len then
        self.recvbuf = ssub(self.recvbuf, len + 1)
    else
        self.recvbuf = ""
    end
end

function WebSocket:peek(len, offset)
    offset = offset or 0
    if offset + len <= #self.recvbuf then
        return ssub(self.recvbuf, offset + 1, offset + len)
    end
end

function WebSocket:send(data)
    if self.alive and data then
        local send_len = self.session.call_text(data)
        return send_len > 0
    end
    log_err("[WebSocket][send] the socket not alive, can't send")
    return false
end

function WebSocket:send_frame(fin, opcode, data)
    local finbit = fin and 0x80 or 0
    local frame = spack("B", finbit | opcode)

    local l = #data
    local mask_bit = self.mask_outgoing and 0x80 or 0
    if l < 126 then
        frame = frame .. spack("B", l | mask_bit)
    elseif l < 0xFFFF then
        frame = frame .. spack(">BH", 126 | mask_bit, l)
    else 
        frame = frame .. spack(">BL", 127 | mask_bit, l)
    end
    frame = frame .. data
    self:send(frame)
end

function WebSocket:send_text(data)
    self:send_frame(true, 0x1, data)
end

function WebSocket:send_binary(data)
    self:send_frame(true, 0x2, data)
end

function WebSocket:send_ping(data)
    self:send_frame(true, 0x9, data)
end

function WebSocket:send_pong(data)
    self:send_frame(true, 0xA, data)
end

function WebSocket:websocket_mask(mask, data, length)
    local umasked = {}
    for i=1, length do
        umasked[i] = string.char(string.byte(data, i) ~ string.byte(mask, (i-1)%4 + 1))
    end
    return table.concat(umasked)
end

function WebSocket:recv_frame_data()
    local frame_length, frame_mask
    if payloadlen < 126 then
        frame_length = payloadlen
    elseif payloadlen == 126 then
        local h_data = self:peek(2, offset)
        if not h_data then
            return false, nil, "Payloadlen 126 read true length error"
        end
        frame_length = sunpack(">H", h_data)
        offset = offset + 2
    else --payloadlen == 127
        local h_data = self:peek(8, offset)
        if not l_data then
            return false, nil, "Payloadlen 127 read true length error"
        end
        frame_length = sunpack(">L", l_data)
        offset = offset + 8
    end
    if mask_frame then
        local mask = self:peek(4, offset)
        if not mask then
            return false, nil, "Masking Key read error"
        end
        frame_mask = mask
        offset = offset + 4
    end

    local  frame_data = ""
    if frame_length > 0 then
        local fdata = self:peek(frame_length, offset)
        if not fdata then
            return false, nil, "Payload data read error:"
        end
        frame_data = fdata
    end
    if mask_frame and frame_length > 0 then
        frame_data = self:websocket_mask(frame_mask, frame_data, frame_length)
    end
    if not final_frame then
        return true, false, frame_data
    end

    if frame_opcode  == 0x1 then -- text
        return true, true, frame_data
    elseif frame_opcode == 0x2 then -- binary
        return true, true, frame_data
    elseif frame_opcode == 0x8 then -- close
        local code, reason
        if #frame_data >= 2 then
            code = sunpack(">H", frame_data:sub(1,2))
        end
        if #frame_data > 2 then
            reason = frame_data:sub(3)
        end
        self:close()
        self.host:on_close(self, code, reason)
    elseif frame_opcode == 0x9 then --Ping
        self:send_pong()
    elseif frame_opcode == 0xA then -- Pong
        self.host:on_socket_pong(self, frame_data)
    end
    return true, true, nil
end

function WebSocket:recv_frame()
    local data = self.recvbuf
    if #data < 2 then
        return true
    end
    local header, payloadlen = sunpack("BB", data)
    local reserved_bits = header & 0x70 ~= 0
    if reserved_bits then
        -- client is using as-yet-undefined extensions
        return false, "Reserved_bits show using undefined extensions"
    end
    local frame_opcode = header & 0xf
    local mask_frame = payloadlen & 0x80 ~= 0
    local frame_opcode_is_control = frame_opcode & 0x8 ~= 0
    payloadlen = payloadlen & 0x7f
    if frame_opcode_is_control and payloadlen >= 126 then
        -- control frames must have payload < 126
        return false, "Control frame payload overload"
    end
    local final_frame = header & 0x80 ~= 0
    if frame_opcode_is_control and not final_frame then
        return false, "Control frame must not be fragmented"
    end
    self:pop(2)
    return _async_call("get_frame_data", self.recv_frame_data)
end

return WebSocket
