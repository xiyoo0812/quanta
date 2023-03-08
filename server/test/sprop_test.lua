-- sprop_test.lua
import("store/db_property.lua")

local SPlayer   = import("test/store/splayer.lua")

local player = SPlayer()

player:set_level(100)
player:set_name("aaa")
player:set_games({1, 2, 3})

player:set_main_task(1001)
player:add_task(1001, 2)
player:add_task(1002, 3)
player:add_task(1003, 4)
player:del_task(1001)

player:add_packet(1, 20)
player:add_packet(2, 10)
player:add_packet(3, 30)

local packet = player:get_packets(1)
packet:add_item(1, 1001)
packet:add_item(2, 1002)
packet:add_item(3, 1003)
packet:add_item(4, 1004)
packet:set_items_field(4)

packet:del_item(2)
player:del_packet(1)
