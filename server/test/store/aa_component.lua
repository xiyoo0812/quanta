-- aa_component.lua
local log_debug     = logger.debug

local PKT   = import("test/store/spacket.lua")

local AAcomponent = mixin()
local prop = db_property(AAcomponent, "packet")
prop:store_value("capacity", 2)     --capacity
prop:store_objects("packets", {})   --packets

function AAcomponent:__init()
    self:load_packet_db()
end

function AAcomponent:on_db_packet_load(sheet)
    log_debug("[SPlayer][on_db_packet_load], sheet:%s", sheet)
end

function AAcomponent:add_packet(id, capacity)
    self:set_packets_field(id, PKT(capacity))
end

function AAcomponent:del_packet(id)
    self:del_packets_field(id)
end

return AAcomponent
