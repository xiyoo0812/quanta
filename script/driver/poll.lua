--poll.lua
local lnet          = require "lnet"

local env_number    = environ.number

local Poll = singleton()
local prop = property(Poll)
prop:accessor("poll", nil)
prop:accessor("sockets", {})

function Poll:__init()
    local max_conn = env_number("QUANTA_MAX_CONN", 1024)
    --创建poll对象
    self.poll = lnet.create_poll(max_conn)
    --加入帧更新
    quanta.join(self)
end

function Poll:__release()
    lnet.destroy_poll(self.poll)
end

function Poll:thread(worker, id, ctxstring)
    return lnet.poll_thread(self.poll, worker, id, ctxstring)
end

function Poll:control(socket, mode, bread, bwrite)
    local fd = socket.fd
    self.sockets[fd] = (mode > 0) and socket or nil
    lnet.control_poll(self.poll, fd, mode, bread, bwrite)
end

function Poll:update()
    local nid = lnet.do_poll(self.poll, 0)
    if nid > 0 then
        for id = 1, nid do
            local fd, bread, bwrite = lnet.get_event(self.poll, id)
            local socket = self.sockets[fd]
            if socket then
                socket:handle_event(bread, bwrite)
            end
        end
    end
end

quanta.poll = Poll()

return Poll
