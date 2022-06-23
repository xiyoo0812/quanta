--oop_test.lua
require "luaoop.enum"
require "luaoop.class"
require "luaoop.mixin"
require "luaoop.property"

local IObject = mixin(
    "test1",
    "test2",
    "test3",
    "test4"
)

local prop = property(IObject)
prop:accessor("key1", 1)
prop:accessor("key2", 2)

function IObject:__init()
end

function IObject:test1()
    print("key1", self:get_key1())
    self:set_key2(4)
    print("key2", self:get_key2())
    self:set_key3(6)
    print("key3", self:get_key3())
end

function IObject:test2()
    print("key2", self.key2)
end

function IObject:test3()
    print("key3", self.key3)
end

local Object = class(nil, IObject)
local prop2 = property(Object)
prop2:accessor("key3", 3)
function Object:__init()
end

function Object:__release()
    print("release", self)
end

function Object:run()
    print("key3", self:get_key3())
    print("key1", self:get_key1())
    print("key2", self:get_key2())
    self:invoke("test1")
end

local TEST1 = enum("TEST1", 0, "ONE", "THREE", "TWO")
print(TEST1.TWO)
local TEST2 = enum("TEST2", 1, "ONE", "THREE", "TWO")
TEST2.FOUR = TEST2()
print(TEST2.TWO, TEST2.FOUR)
local TEST3 = enum("TEST3", 0)
TEST3("ONE")
TEST3("TWO")
TEST3("FOUR", 4)
local five = TEST3("FIVE")
print(TEST3.TWO, TEST3.FOUR, TEST3.FIVE, five)

local obj = Object()
obj:run()

return Object
