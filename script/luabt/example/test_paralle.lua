--test_paralle.lua

local LuaBT     = require "example.luaoop"
local Flee      = require "example.flee"
local Attack    = require "example.attack"
local HpCheck   = require "example.hp_check"

local Parallel  = require "script.parallel"
local Sequence  = require "script.sequence"

local robot = {id = 1, hp = 100}

local root = Parallel(
    luabt.FAIL_ONE,
    luabt.SUCCESS_ALL,
    Sequence(
        HpCheck(50),
        Flee(5)
    ),
    Attack(20)
)

-- print(inspect(root))
local bt = LuaBT(robot, root)
-- print(inspect(Tick))
for i = 1, 30 do
    print("================", i)
    if i == 5 then
        print(">>>>>>>> hp == 10")
        robot.hp = 10
    end
    if i == 18 then
        print(">>>>>>>> hp == 100")
        robot.hp = 100
    end
    bt:tick()
end
