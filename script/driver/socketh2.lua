--socketh2.lua
local Socketls      = import("driver/socketls.lua")

local schar         = string.char
local log_info      = logger.info
local log_debug     = logger.debug
local tunpack       = table.unpack
local tcopy         = table.copy
local lnext_id      = luakit.next_id
local http2ccodec   = codec.http2ccodec
local grpcccodec    = codec.grpcccodec

local thread_mgr    = quanta.get("thread_mgr")

local HTTP_TIMEOUT  = quanta.enum("NetwkTime", "HTTP_CALL_TIMEOUT")

local H2_FRAME      = codec.h2_frame_type

local ERROR = {
	[0x00] = "Graceful shutdown",
	[0x01] = "Protocol error detected",
	[0x02] = "Implementation fault",
	[0x03] = "Flow-control limits exceeded",
	[0x04] = "Settings not acknowledged",
	[0x05] = "Frame received for closed stream",
	[0x06] = "Frame size incorrect",
	[0x07] = "Stream not processed",
	[0x08] = "Stream cancelled",
	[0x09] = "Compression state not updated",
	[0x0a] = "TCP connection error for CONNECT method",
	[0x0b] = "Processing capacity exceeded",
	[0x0c] = "Negotiated TLS parameters not acceptable",
	[0x0d] = "Use HTTP/1.1 for the request",
}

local SocketH2 = class(Socketls)
local prop = property(SocketH2)
prop:reader("h2_handshake", false)  --handshake
prop:reader("window_size", nil)     --window_size
prop:reader("stream_id", 1)         --stream_id
prop:reader("settings", {})         --settings
prop:reader("streams", {})          --streams
prop:reader("protocol", "h2")       --protocol

function SocketH2:__init(host, ip, port)
    local alpn_proto = "h2"
    self.alpn_protos = schar(#alpn_proto) .. alpn_proto
end

function SocketH2:options(protocol, tls_enable)
    self.tls_enable = tls_enable
    self.protocol = protocol
end

function SocketH2:new_h2_codec()
    if self.protocol == "h2" then
        return http2ccodec()
    end
    return grpcccodec()
end

function SocketH2:on_tls_handshaked()
    self:send_data("PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n")
    local h2codec = self:new_h2_codec()
    local handshake_id = lnext_id()
    h2codec.h2_handshaked = function()
        thread_mgr:response(handshake_id, true)
    end
    self:set_codec(h2codec)
    self:send_frame(H2_FRAME.SETTINGS)
    local ok, res = thread_mgr:yield(handshake_id, self.ip, HTTP_TIMEOUT)
    if not ok then
        self:close()
        return ok, res
    end
    return true
end

function SocketH2:on_h2_handshake(streams)
    for _, stream in ipairs(streams) do
        self:on_h2_ctrl_frame(stream)
    end
    if self.h2_handshake then
        log_info("[SocketH2][on_h2_handshake] h2 handshake success!")
        local codec = self.tls_codec or self.codec
        codec.h2_handshaked()
    end
end

function SocketH2:on_socket_recv(...)
    if self.h2_handshake then
        return self:on_streams_recv(...)
    end
    if self.tls_handshake then
        return self:on_h2_handshake(...)
    end
    self:on_tls_handshake(...)
end

function SocketH2:on_streams_recv(streams)
    for _, stream in ipairs(streams) do
        local stream_id = stream[1]
        if stream_id > 0 then
            local session_id = self.streams[stream_id]
            if session_id then
                self.streams[stream_id] = nil
                local code, status, headers, body = tunpack(stream, 2)
                if code > 0 then
                    thread_mgr:response(session_id, false, code, ERROR[code])
                else
                    thread_mgr:response(session_id, true, status, body, headers)
                end
            else
                self.host:on_socket_recv(self, tunpack(stream, 2))
            end
        else
            self:on_h2_ctrl_frame(stream)
        end
    end
end

--控制帧
function SocketH2:on_h2_ctrl_frame(stream)
    local ack, settings, winsize, timestamp, goaway_id, code, err =  tunpack(stream, 2)
    if goaway_id > 0 then
        log_debug("[SocketH2][GOAWAY] client({}) last_id({}), error({}:{})!", self.token, goaway_id, code, err)
        self.host:on_socket_error(self, "http2 goaway")
        self:close()
        return
    end
    if not self.h2_handshake then
        self.h2_handshake = ack
    end
    if next(settings) then
        log_debug("[SocketH2][SETTINGS] client({}) ack({}), settings({})!", self.token, ack, settings)
        tcopy(settings, self.settings)
    end
    if winsize > 0 then
        log_debug("[Http2Client][WINDOW_UPDATE] client({}) winsize({})!", self.token, winsize)
        self.winsize = winsize
    end
    if timestamp > 0 then
        log_debug("[Http2Client][PING] client({}) timestamp({})!", self.token, timestamp)
    end
end

function SocketH2:ping()
    self:send_data(0, H2_FRAME.PING, quanta.now_ms)
end

--发送控制帧
function SocketH2:send_frame(frame, ...)
    log_debug("[SocketH2][send_frame] client(token:{}) frame({})!", self.token, frame)
    self:send_data(0, frame, ...)
end

function SocketH2:send_packet(url, ...)
    if self.alive then
        local stream_id = self.stream_id
        local send_len = self.session.call_data(stream_id, url, ...)
        if send_len <= 0 then
            return false, "send data failed"
        end
        local session_id = lnext_id()
        self.streams[stream_id] = session_id
        self.stream_id = stream_id + 2
        return thread_mgr:yield(session_id, url, HTTP_TIMEOUT)
    end
    return false, "socket not alive"
end

return SocketH2
