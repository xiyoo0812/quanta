--socket.lua
local lnet          = require "lnet"

local log_err       = logger.err
local poll          = quanta.poll

local Socket = class()
local prop = property(Socket)
prop:accessor("fd", nil)
prop:accessor("ip", nil)
prop:accessor("host", nil)
prop:accessor("listener", nil)
prop:accessor("port", 0)
prop:accessor("sndbuf", "")
prop:accessor("recvbuf", "")

function Socket:__init(host)
    self.host = host
end

function Socket:__release()
   self:close()
end

function Socket:close(close_by_peer)
    if self.fd then
        poll:control(self, 0)
        lnet.close(self.fd)
        self.fd = nil
        if close_by_peer then
            self.host:on_socket_close(self)
        end
    end
end

function Socket:listen(listener, ip, port)
    if self.fd then
        return self.fd
    end
    local fd, terr = lnet.tcp(ip, port)
    if fd < 0 then
        log_err("[Socket][listen] create tcp failed: %s", terr)
        return
    end
    local res, lerr = lnet.listen(fd)
    if res < 0 then
        log_err("[Socket][listen] listen tcp failed: %s", lerr)
        return
    end
    self.listener = listener
    self.fd, self.ip, self.port = fd, ip, port
    poll:control(self, 1, true, false)
    return fd
end

function Socket:connect(ip, port)
    local fd, terr = lnet.tcp()
    if fd < 0 then
        log_err("[Socket][connect] create tcp failed: %s", terr)
        return
    end
    local res, cerr = lnet.connect(fd, ip, port)
    if res < 0 then
        log_err("[Socket][connect] connect failed: %s", cerr)
        return
    end
    self.fd, self.ip, self.port = fd, ip, port
    poll:control(self, 1, true, false)
    return fd
end

function Socket:accept(fd)
    local newfd, err, ip, port = lnet.accept(fd)
    if newfd < 0 then
        log_err("[Socket][accept] accept tcp failed: %s", err)
        return
    end
    self.fd, self.ip, self.port = fd, ip, port
    poll:control(self, 1, true, false)
    self.host:on_socket_accept(self)
end

function Socket:recv()
    if not self.fd then
        return false
    end
    local ret, data_oe = lnet.recv(self.fd, 8000)
    if ret < 0 then
        log_err("[Socket][recv] recv failed: %s", data_oe)
        self:close(true)
        return false
    end
    self.recvbuf = self.recvbuf .. data_oe
    self.host:on_socket_recv(self)
    return true
end

function Socket:peek(len, offset)
    offset = offset or 0
    if offset + len <= #self.recvbuf then
        return self.recvbuf:sub(offset + 1, offset + len)
    end
end

function Socket:pop(len)
    if #self.recvbuf > len then
        self.recvbuf = self.recvbuf:sub(len + 1)
    elseif #self.recvbuf == len then
        self.recvbuf = ""
    end
end

function Socket:send(data)
    if not self.fd then
        return false
    end
    if data then
        self.sndbuf = self.sndbuf..data
    end
    local sndlen, err = lnet.send(self.fd, self.sndbuf)
    if sndlen < 0 then
        log_err("[Socket][send] send failed: %s", err)
        self:close(true)
        return false
    end
    if sndlen > 0 then
        if sndlen == #self.sndbuf then
            self.sndbuf = ""
            poll:control(self, 2, true, false)
        else
            self.sndbuf = self.sndbuf:sub(sndlen + 1)
            poll:control(self, 2, true, true)
        end
    end
	return true
end

function Socket:handle_event(bread, bwrite)
    if self.listener and bread then
        local socket = Socket(self.listener)
        socket:accept(self.fd)
        return
    end
    if bread then
        if not self:recv() then
            return
        end
    end
    if bwrite then
        self:send()
    end
end

return Socket
