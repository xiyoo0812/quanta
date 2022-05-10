# Lua 行为树

## 特点

* 行为树不保存状态，所以多个执行逻辑相同的实例可以共享同一个行为树。
* 实例的执行状态保存在 bt tree 当中。bt tree 充当黑板。
* 简单，灵活，占用内存小。

## 依赖
* [lua](https://github.com/xiyoo0812/lua.git)5.2以上
* [luaoop](https://github.com/xiyoo0812/luaoop.git)

## 实现细节

如果前后两次 tick 返回的 running 节点不一致，那么就存在前一个 running 节点没有关闭的可能性。这时候需要检查前面的那个节点是否仍然打开，如果是打开则手动关闭。

一个 running A 打断 running B 的时候，如何优雅的关闭 B 节点。
现在的实现，是先 open A/run A，再 close B。而符合逻辑做法应该是先关闭 B，再启动 A。
一个可能的解决办法是：在进入一个 running 节点的时候，并不立即执行真正的逻辑，
而是等待一帧再执行。这样的缺点是显而易见的，AI 反应比较迟钝。慢了一拍。

我们可以通过记录节点的状态。is_open = true。
open 的时候需要往黑板写入 is_open 状态。
close 的时候需要往黑板清除 is_open 状态。

## 扩展节点

每个节点有三个回调函数：

* open(tick)
    * return SUCCESS, FAIL, 不执行 run，提前返回
    * return nil, 继续执行 run
* run(tick)
    * return RUNNING, FAIL, SUCCEED
* close(tick)

tick 是为 AI 分配的行为树运行实例。每一帧执行一次 tick 实例的 tick 函数。

```lua
local Luabt = require "source.luabt"

local node = class()

-- return Luabt.SUCCESS, Luabt.FAIL, nil
function node:open()
end

-- return Luabt.SUCCESS, Luabt.FAIL, Luabt.RUNNING
function node:run()
end

function node:close()
end

return node
```

## Example
备注: 需要先下载luaoop
```
lua example/test_paralle.lua
lua example/test_priority.lua
```
