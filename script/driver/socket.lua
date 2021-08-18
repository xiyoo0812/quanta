--socket.lua
local lnet          = require("lnet")

local log_err       = logger.err
local lrecv         = lnet.recv
local lsend         = lnet.send
local ssub          = string.sub
local sfind         = string.find
local qxpcall       = quanta.xpcall

local POLL_DEL      = 0
local POLL_ADD      = 1
local POLL_MOD      = 2
local NetwkTime     = enum("NetwkTime")

local poll          = quanta.get("poll")
local thread_mgr    = quanta.get("thread_mgr")

local Socket = class()
local prop = property(Socket)
prop:accessor("fd", nil)
prop:accessor("ip", nil)
prop:accessor("host", nil)
prop:accessor("block_id", nil)
prop:accessor("listener", false)
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
        poll:control(self, POLL_DEL)
        if close_by_peer then
            self.host:on_socket_close(self, self.fd)
        end
        lnet.close(self.fd)
        self.fd = nil
    end
end

function Socket:listen(ip, port)
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
    self.listener = true
    self.fd, self.ip, self.port = fd, ip, port
    poll:control(self, POLL_ADD, true, false)
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
    self.fd = fd
    self.block_id = thread_mgr:build_session_id()
    poll:control(self, POLL_ADD, false, true)
    local ok, err = thread_mgr:yield(self.block_id, "connect", NetwkTime.CONNECT_TIMEOUT)
    if not ok then
        log_err("[Socket][connect] connect failed: %s", err)
        self:close()
        return
    end
    self.block_id = nil
    self.ip, self.port = ip, port
    poll:control(self, POLL_MOD, true, false)
    return fd
end

function Socket:accept(fd)
    local newfd, err, ip, port = lnet.accept(fd)
    if newfd < 0 then
        log_err("[Socket][accept] accept tcp failed: %s", err)
        return
    end
    self.fd, self.ip, self.port = newfd, ip, port
    poll:control(self, POLL_ADD, true, false)
    self.host:on_socket_accept(self, newfd)
end

function Socket:on_recv(fd)
    if #self.recvbuf > 0 then
        qxpcall(self.host.on_socket_recv, "on_socket_recv: %s", self.host, self, self.fd)
    end
end

function Socket:recv()
    if not self.fd then
        return false
    end
    while true do
        local ret, data_oe = lrecv(self.fd, 8000)
        if ret == 0 then
            break
        end
        if ret < 0 then
            self:on_recv()
            log_err("[Socket][recv] recv failed: %s", data_oe)
            self:close(true)
            return false
        end
        self.recvbuf = self.recvbuf .. data_oe
    end
    self:on_recv()
    return true
end

function Socket:peek(len, offset)
    offset = offset or 0
    if offset + len <= #self.recvbuf then
        return ssub(self.recvbuf, offset + 1, offset + len)
    end
end

function Socket:peek_line(line_flag, offset)
    offset = offset or 0
    local i, j = sfind(self.recvbuf, line_flag, offset + 1)
    if i then
        return ssub(self.recvbuf, 1, i - 1), j
    end
end

function Socket:pop(len)
    if #self.recvbuf > len then
        self.recvbuf = ssub(self.recvbuf, len + 1)
    elseif #self.recvbuf == len then
        self.recvbuf = ""
    end
end

function Socket:send(data)
    if not self.fd then
        return false
    end
    if data then
        self.sndbuf = self.sndbuf .. data
    end
    if #self.sndbuf == 0 then
        return true
    end
    while true do
        local sndlen, err = lsend(self.fd, self.sndbuf)
        if sndlen == 0 then
            poll:control(self, POLL_MOD, true, true)
            break
        end
        if sndlen < 0 then
            log_err("[Socket][send] send failed: %s", err)
            self:close(true)
            return false
        end
        if sndlen > 0 then
            if sndlen == #self.sndbuf then
                poll:control(self, POLL_MOD, true, false)
                self.sndbuf = ""
                break
            else
                self.sndbuf = ssub(self.sndbuf, sndlen + 1)
            end
        end
    end
	return true
end

function Socket:handle_event(bread, bwrite)
    if bwrite then
        if self.block_id then
            thread_mgr:response(self.block_id, true)
            return
        end
        if not self:send() then
            return
        end
    end
    if bread then
        if self.listener then
            local socket = Socket(self.host)
            socket:accept(self.fd)
            return
        end
        self:recv()
    end
end

return Socket