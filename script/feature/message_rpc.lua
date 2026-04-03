--message_rpc.lua

local FLAG_RES  = luabus.proto_flag.RES

local SUCCESS   = quanta.enum("KernCode", "SUCCESS")

local Message   = import("feature/message.lua")

local MessageRpc = class(Message)
local prop = property(MessageRpc)
prop:reader("rpc", "")
prop:reader("source", "")

function MessageRpc:__init(session, session_id, len, source, rpc)
    self.source = source
    self.rpc = rpc
end

function MessageRpc:callback(...)
    if not self.reply then
        self.reply = true
        if self.session_id > 0 then
            self.session.callback_target(self.rpc, self.session_id, self.source, FLAG_RES, ...)
        end
    end
end

function MessageRpc:on_defer()
    self:callback(SUCCESS)
end

return MessageRpc
