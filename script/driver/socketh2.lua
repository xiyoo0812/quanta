--socketh2.lua
local Socketls      = import("driver/socketls.lua")

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
    self.alpn_protos = "h2"
end

function SocketH2:close()
    self.stream_id = 1
    self.streams = {}
    self.settings = {}
    self.h2_handshake = false
    Socketls.close(self)
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

function SocketH2:is_ready()
    return self.h2_handshake
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

function SocketH2:on_socket_error(token, err)
    self.stream_id = 1
    self.streams = {}
    self.settings = {}
    self.h2_handshake = false
    Socketls.on_socket_error(self, token, err)
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
                    thread_mgr:response(session_id, true, status, body, headers, stream_id)
                end
            else
                self.host:on_socket_recv(self, stream_id, tunpack(stream, 2))
            end
        else
            self:on_h2_ctrl_frame(stream)
        end
    end
end

--控制帧
function SocketH2:on_h2_ctrl_frame(stream)
    local ack, settings, winsize, timestamp, goaway_id, code, err, ping_ack, frame_type = tunpack(stream, 2)
    if frame_type == H2_FRAME.GOAWAY then
        log_debug("[SocketH2][GOAWAY] client({}) last_id({}), error({}:{})!", self.token, goaway_id, code, err)
        self.host:on_socket_error(self, self.token, "http2 goaway")
        self:close()
        return
    end
    if frame_type == H2_FRAME.SETTINGS then
        if ack then
            self.h2_handshake = true
        else
            self:send_frame(H2_FRAME.SETTINGS, true)
        end
        if next(settings) then
            log_debug("[SocketH2][SETTINGS] client({}) ack({}), settings({})!", self.token, ack, settings)
            tcopy(settings, self.settings)
        end
        return
    end
    if frame_type == H2_FRAME.WINDOW_UPDATE then
        log_debug("[Http2Client][WINDOW_UPDATE] client({}) winsize({})!", self.token, winsize)
        self.window_size = winsize
        return
    end
    if frame_type == H2_FRAME.PING then
        if not ping_ack then
            --收到未带 ack 的 PING, 必须回 PING ack (RFC 7540 6.7)
            self:send_frame(H2_FRAME.PING, true, timestamp)
        end
    end
end

function SocketH2:ping()
    self:send_data(0, H2_FRAME.PING, false, quanta.now_ms)
end

--重置指定stream(服务端会清掉该stream上的所有watcher), error_code默认CANCEL(8)
function SocketH2:send_rst_stream(stream_id, code)
    self:send_frame(H2_FRAME.RST_STREAM, stream_id, code or 8)
end

--发送控制帧
function SocketH2:send_frame(frame, ...)
    self:send_data(0, frame, ...)
end

function SocketH2:send_packet(url, ...)
    if self.h2_handshake then
        local stream_id = self.stream_id
        local send_len = self.session.call_text(stream_id, url, ...)
        if send_len <= 0 then
            return false, "send data failed"
        end
        local session_id = lnext_id()
        self.streams[stream_id] = session_id
        self.stream_id = stream_id + 2
        return thread_mgr:yield(session_id, url, HTTP_TIMEOUT)
    end
    return false, "socket not handshake"
end

return SocketH2
