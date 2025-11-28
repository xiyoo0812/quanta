--socketls.lua
local Socket        = import("driver/socket.lua")

local log_info      = logger.info
local stlscodec     = ssl.tlscodec
local lnext_id      = luakit.next_id
local httpccodec    = codec.httpccodec
local content_codec = codec.set_content_codec

local thread_mgr    = quanta.get("thread_mgr")

local TIMEOUT       = quanta.enum("NetwkTime", "CONNECT_TIMEOUT")
local HTTP_TIMEOUT  = quanta.enum("NetwkTime", "HTTP_CALL_TIMEOUT")

local Socketls = class(Socket)
local prop = property(Socketls)
prop:reader("tls_handshake", false) --handshake
prop:reader("alpn_protos", nil)     --alpn_protos
prop:reader("tls_codec", nil)       --tls_codec
prop:accessor("tls_enable", true)   --tls_enable

function Socketls:__init(host, ip, port)
end

function Socketls:set_codec(codec)
    if self.codec then
        self.codec.set_codec(codec)
        self.tls_codec = codec
    else
        Socket.set_codec(self, codec)
    end
end

function Socketls:set_content_codec(content, codec)
    content_codec(self.tls_codec or self.codec, content, codec)
end

function Socketls:on_tls_handshake(codec, message)
    if message then
        self:send_data(message)
    end
    if codec.isfinish() then
        self.tls_handshake = true
        codec.tls_handshaked()
    end
end

function Socketls:on_tls_handshaked()
    self:set_codec(httpccodec())
    return true
end

function Socketls:on_socket_connected()
    if self.tls_enable then
        local tlscodec = stlscodec(true, self.alpn_protos)
        local handshake_id = lnext_id()
        tlscodec.tls_handshaked = function()
            thread_mgr:response(handshake_id, true)
        end
        self:set_codec(tlscodec)
        self:send_data()
        local ok, res = thread_mgr:yield(handshake_id, self.ip, TIMEOUT)
        if not ok then
            self:close()
            return ok, res
        end
    else
        self.tls_handshake = true
    end
    log_info("[Socketls][on_socket_connected] tls handshake success!")
    return self:on_tls_handshaked()
end

function Socketls:on_socket_recv(...)
    if self.tls_handshake then
        return self:on_http_recv(...)
    end
    self:on_tls_handshake(...)
end

function Socketls:on_http_recv(session_id, status, headers, body)
    thread_mgr:response(session_id, true, status, body, headers)
end

function Socketls:send_packet(url, ...)
    if self.alive then
        local session_id = lnext_id()
        local send_len = self.session.call_data(session_id, url, ...)
        if send_len <= 0 then
            return false, "send data failed"
        end
        return thread_mgr:yield(session_id, url, HTTP_TIMEOUT)
    end
    return false, "socket not alive"
end

return Socketls
