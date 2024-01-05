-- msg_mgr.lua


local MsgMgr = singleton()
local prop = property(MsgMgr)
prop:reader("accord_group", {})     -- 协议分组(解析proto)

function MsgMgr:__init()
end

function MsgMgr:register(cmd_id)
end


quanta.msg_mgr = MsgMgr()

return MsgMgr
