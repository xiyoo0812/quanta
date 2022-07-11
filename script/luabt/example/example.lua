--test_select.lua

require("luaoop.enum")
require("luaoop.class")
require("luaoop.mixin")
require("luaoop.property")

local LuaBT     = require("luabt.luabt")

local Flee      = require "example.flee"
local Health    = require "example.health"
local Fight     = require "example.fight"
local HpCheck   = require "example.hp_check"

local Random    = luabt.Random
local Repeat    = luabt.Repeat
local Sequence  = luabt.Sequence

local robot = {id = 1, hp = 100}

local root = Sequence(
    HpCheck(Health(), Flee(), 30),
    Random(Fight(), Health()),
    Repeat(Flee(), 5)
)

local bt = LuaBT(robot, root)
for i = 1, 30 do
    print("================", i)
    if i == 10 then
        print(">>>>>>>> hp == 10")
        robot.hp = 10
    end
    if i == 18 then
        print(">>>>>>>> hp == 100")
        robot.hp = 100
    end
    bt:tick()
end
