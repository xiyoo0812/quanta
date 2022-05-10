# luaoop
一个 lua 面向对象机制的实现。

# 依赖
- [lua](https://github.com/xiyoo0812/lua.git)5.2以上，（析构需要lua5.4）

# 功能
- 支持class
- 支持enum
- 支持单例
- 支持构造（__init）和析构(__release)
- 支持mixin，export的接口会代理到class上，直接使用class进行调用
- 支持使用accessor，reader，writer声明成员，并生成get/set方法
- 多个mixin的同名非导出接口可以使用invoke进行串行调用，使用collect串行调用并收集执行结果。

# 限制
- 访问限制暂时没有
- 析构有限制，只能在gc的时候调用，会有延迟
- 仅支持单继承，使用mixin机制扩展多继承，export函数重名会告警
- 一个lua文件仅能声明一个class和mixin，主要是不想在声明类的时候带上类名参数，使用了文件名作为类标识，如果不喜欢可以修改实现。
```lua
--当前声明类方式
local ACLASS = class()
--不想使用下面这种方式
local ACLASS = class("ACLASS")
```

# 测试代码
- lua test/oop_test.lua

# 使用方法
```lua
--enum枚举定义
--枚举名称，起始值，枚举变量列表
local TEST1 = enum("TEST1", 0, "ONE", "THREE", "TWO")
print(TEST1.TWO)

--枚举定义
local TEST2 = enum("TEST2", 1, "ONE", "THREE", "TWO")
--使用枚举名定义新值，会在原来基础上累加
TEST2.FOUR = TEST2()
print(TEST2.TWO, TEST2.FOUR)

--使用下面方式定义会更优雅一点吧
local TEST3 = enum("TEST3", 0)
TEST3("ONE")
TEST3("TWO")
TEST3("FOUR", 4)
--新定义会返回新值
local five = TEST3("FIVE")

print(TEST3.TWO, TEST3.FOUR, TEST3.FIVE, five)

--mixin定义
--mixin类似多继承，但是继承强调i'am，而mixin强调i'can.
--mixin无法实例化，必须依附到class上，mixin函数的self都是属主class对象
--mixin除了不能实例化，其他和class使用方式一致
--mixin export的接口会代理到class上，直接使用class进行调用
local IObject = mixin(
    "test1",
    "test2",
    "test3",
    "test4"
)
--使用property定义属性，并生成get/set方法
local prop = property(IObject)
prop:accessor("key1", 1)
prop:accessor("key2", 2)

--构造函数
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

--声明一个类
--第一个函数为父类，后面是mixin接口列表
local Object = class(nil, IObject)
local prop2 = property(Object)
prop2:accessor("key3", 3)
--构造函数
function Object:__init()
end

--析构函数
function Object:__release()
    print("release", self)
end

function Object:run()
    print("key3", self:get_key3())
    print("key1", self:get_key1())
    print("key2", self:get_key2())
    self:invoke("test1")
end

--声明单例，和class一样使用
local AAMgr = singleton(nil, IObject)
function AAMgr:__init()
end

--创建单例对象
local aamgr = AAMgr.inst()

--创建一个对象，并调用函数
local obj = Object()
obj:run()

```