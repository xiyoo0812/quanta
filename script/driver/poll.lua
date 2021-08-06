--poll.lua
local lnet          = require("lnet")

local lpoll         = lnet.do_poll
local levent        = lnet.get_event
local lcontrol      = lnet.control_poll
local env_number    = environ.number

local update_mgr    = quanta.get("update_mgr")

local Poll = singleton()
local prop = property(Poll)
prop:reader("poll", nil)
prop:reader("sockets", {})

function Poll:__init()
    local max_conn = env_number("QUANTA_MAX_CONN", 1024)
    --创建poll对象
    self.poll = lnet.create_poll(max_conn)
    --加入帧更新
    update_mgr:attach_frame(self)
    --退出通知
    update_mgr:attach_quit(self)
end

function Poll:on_quit()
    lnet.destroy_poll(self.poll)
end

function Poll:thread(worker, id, ctxstring)
    return lnet.poll_thread(self.poll, worker, id, ctxstring)
end

function Poll:control(socket, mode, bread, bwrite)
    local fd = socket.fd
    self.sockets[fd] = (mode > 0) and socket or nil
    lcontrol(self.poll, fd, mode, bread, bwrite)
end

function Poll:on_frame()
    local nid = lpoll(self.poll, 0)
    if nid > 0 then
        for id = 1, nid do
            local fd, bread, bwrite = levent(self.poll, id)
            local socket = self.sockets[fd]
            if socket then
                socket:handle_event(bread, bwrite)
            end
        end
    end
end

quanta.poll = Poll()

return Poll
