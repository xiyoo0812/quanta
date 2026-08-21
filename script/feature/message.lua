--message.lua
local tclean        = table.clean

local thread_mgr    = quanta.get("thread_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local FLAG_REQ      = luabus.proto_flag.REQ
local FLAG_RES      = luabus.proto_flag.RES
local RELAY_CLIENT  = luabus.relay_type.CLIENT

local Message = class()
local prop = property(Message)
prop:reader("len", 0)
prop:reader("flag", 0)
prop:reader("cmd_id", 0)
prop:reader("target_id", 0)
prop:reader("session_id", 0)
prop:reader("session", nil)
prop:reader("reply", false)
prop:reader("lockeys", {})
prop:reader("request", {})
prop:reader("response", {})

function Message:__init(session, session_id, len, req, cmd_id, flag, target_id)
    self.len = len
    self.flag = flag
    self.request = req
    self.cmd_id = cmd_id
    self.session = session
    self.target_id = target_id
    self.session_id = session_id
end

function Message:lock(key, waiting)
    if thread_mgr:lock(key, waiting) then
        self.lockeys[key] = true
        return true
    end
    return false
end

function Message:callback_code(code)
    self.response.error_code = code
    self:callback()
end

function Message:callback()
    if not self.reply then
        self.reply = true
        if self.flag == FLAG_REQ and self.session_id > 0 then
            local callback_id = protobuf_mgr:callback_id(self.cmd_id)
            if callback_id > 0 then
                self.session.call_client(callback_id, FLAG_RES, RELAY_CLIENT, self.session_id, self.target_id, self.response)
                return
            end
        end
    end
end

function Message:__defer()
    self:callback()
    tclean(self.request)
    tclean(self.response)
    for key in pairs(self.lockeys) do
        thread_mgr:unlock(key)
    end
    tclean(self.lockeys)
    self.session = nil
    self.reply = false
end

return Message