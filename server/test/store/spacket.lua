-- etcd_test.lua

local ITM   = import("test/store/sitem.lua")

local SPacket = class()
local prop = db_property(SPacket, "packet")
prop:store_value("capacity", 2)     --level
prop:store_objects("items", {})     --items

function SPacket:__init(capacity)
    self.capacity = capacity
end

function SPacket:add_item(id, pid)
    self:set_items_field(id, ITM(pid))
end

function SPacket:del_item(id)
    self:del_items_field(id)
end

function SPacket:serialize()
    local items = {}
    for uid, item in pairs(self.items) do
        items[uid] = item:serialize()
    end
    return {
        items = items,
        capacity = self.capacity,
    }
end

return SPacket
