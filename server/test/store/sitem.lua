-- sitem.lua

local SItem = class()
local prop = db_property(SItem, "packet")
prop:store_value("proto_id", 2)     --proto_id
prop:store_value("time", 2)         --time
prop:store_value("explire", 2)      --explire

function SItem:__init(id, pid)
    self.id = id
    self.proto_id = pid
end

function SItem:serialize()
    return {
        id = self.id,
        time = self.time,
        explire = self.explire,
        proto_id = self.proto_id,
    }
end

return SItem
