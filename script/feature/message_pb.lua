--message_pb.lua
local tclean        = table.clean

local protobuf_mgr  = quanta.get("protobuf_mgr")

local FLAG_REQ      = luabus.proto_flag.REQ
local FLAG_RES      = luabus.proto_flag.RES
local RELAY_CLIENT  = luabus.relay_type.CLIENT

local Message       = import("feature/message.lua")

local MessagePb = class(Message)
local prop = property(MessagePb)
prop:reader("flag", 0)
prop:reader("cmd_id", 0)
prop:reader("player_id", 0)
prop:reader("request", {})
prop:reader("response", {})

function MessagePb:__init(session, session_id, len, req, cmd_id, flag, player_id)
    self.flag = flag
    self.request = req
    self.cmd_id = cmd_id
    self.player_id = player_id
end

function MessagePb:callback_code(code)
    self.response.error_code = code
    self:callback()
end

function MessagePb:callback()
    if not self.reply then
        self.reply = true
        if self.flag == FLAG_REQ and self.session_id > 0 then
            local callback_id = protobuf_mgr:callback_id(self.cmd_id)
            if callback_id > 0 then
                self.session.call_client(callback_id, FLAG_RES, RELAY_CLIENT, self.session_id, self.player_id, self.response)
                return
            end
        end
    end
end

function MessagePb:on_defer()
    self:callback()
    tclean(self.request)
    tclean(self.response)
end

return MessagePb