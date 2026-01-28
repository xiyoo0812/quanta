--message.lua
local tclean        = table.clean

local thread_mgr    = quanta.get("thread_mgr")

local Message = class()
local prop = property(Message)
prop:reader("len", 0)
prop:reader("session", nil)
prop:reader("session_id", 0)
prop:reader("reply", false)
prop:reader("lockeys", {})

function Message:__init(session, session_id, len)
    self.len = len
    self.session = session
    self.session_id = session_id
end

function Message:lock(key, waiting)
    if thread_mgr:lock(key, waiting) then
        self.lockeys[key] = true
        return true
    end
    return false
end

function Message:on_defer()
end

function Message:__defer()
    self:on_defer()
    for key in pairs(self.lockeys) do
        thread_mgr:unlock(key)
    end
    tclean(self.lockeys)
    self.session = nil
    self.reply = false
end

return Message