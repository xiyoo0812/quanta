# lworker
一个基于C++17的Lua多任务调度库！。

# 依赖
- [lua](https://github.com/xiyoo0812/lua.git)5.2以上
- [fmt](https://github.com/fmtlib/fmt.git)
- [luakit](https://github.com/xiyoo0812/luakit.git)
- [lcodec](https://github.com/xiyoo0812/lcodec.git)
- 项目路径如下<br>
  |--proj <br>
  &emsp;|--lua <br>
  &emsp;|--fmt <br>
  &emsp;|--luakit <br>
  &emsp;|--lcodec <br>
  &emsp;|--lworker

# 编译
- msvc: 准备好lua依赖库并放到指定位置，将proj文件加到sln后编译。
- linux: 准备好lua依赖库并放到指定位置，执行make -f lworker.mak

# 注意事项
- mimalloc: 参考[quanta](https://github.com/xiyoo0812/quanta.git)使用，不用则在工程文件中注释

# 用法
```lua
--主线程
--worker_test.lua
import("lua/scheduler.lua")

local log_err       = logger.err
local log_debug     = logger.debug

local scheduler     = quanta.get("scheduler")
local timer_mgr     = quanta.get("timer_mgr")

scheduler:setup("quanta")
scheduler:startup("wtest", "wtest")

timer_mgr:loop(2000, function()
    local ok, res1, res2 = scheduler:call("wtest", "test_rpc", 1, 2, 3, 4)
    if not ok then
        log_err("[scheduler][call] call failed: %s", res1)
        return
    end
    log_debug("[scheduler][call] call success: %s, %s", res1, res2)
end)

--任务线程
--wtest.lua
import("lua/worker.lua")

local log_debug     = logger.debug
local event_mgr     = quanta.get("event_mgr")

local WorkerTest = class()

function WorkerTest:__init()
    event_mgr:add_listener(self, "test_rpc")
end

function WorkerTest:test_rpc(a, b, c, d)
    log_debug("[WorkerTest][test_rpc] %s, %s, %s, %s", a, b, c, d)
    return a + b, c + d
end

quanta.startup(function()
    quanta.qtest1 = WorkerTest()
end)

```