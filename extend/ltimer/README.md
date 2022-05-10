# ltimer
一个给lua使用的时间库，包括常用的时间函数以及高性能定时器！

# 依赖
- [lua](https://github.com/xiyoo0812/lua.git)5.2以上
- [luakit](https://github.com/xiyoo0812/luakit.git)一个luabind库
- 项目路径如下<br>
  |--proj <br>
  &emsp;|--lua <br>
  &emsp;|--ltimer <br>
  &emsp;|--luakit <br>

# 编译
- msvc: 准备好lua依赖库并放到指定位置，将proj文件加到sln后编译。
- linux: 准备好lua依赖库并放到指定位置，执行make -f ltimer.mak

# 用法
```lua
--本示例使用了quanta引擎
--https://github.com/xiyoo0812/quanta.git
--timer_mgr.lua
local ltimer    = require("ltimer")
local lcrypt    = require("lcrypt")

local ipairs    = ipairs
local ltime     = ltimer.time
local tpack     = table.pack
local tunpack   = table.unpack
local new_guid  = lcrypt.guid_new

--定时器精度，20ms
local TIMER_ACCURYACY = 20

local driver        = ltimer.new()
local thread_mgr    = quanta.get("thread_mgr")

local TimerMgr = singleton()
local prop = property(TimerMgr)
prop:reader("timers", {})
prop:reader("last_ms", 0)
prop:reader("escape_ms", 0)
function TimerMgr:__init()
    self.last_ms = ltime()
end

function TimerMgr:trigger(handle, now_ms)
    if handle.times > 0 then
        handle.times = handle.times - 1
    end
    local function timer_cb()
        handle.params[#handle.params] = now_ms - handle.last
        handle.cb(tunpack(handle.params))
    end
    --防止在定时器中阻塞
    thread_mgr:fork(timer_cb)
    --更新定时器数据
    handle.last = now_ms
    if handle.times == 0 then
        self.timers[handle.timer_id] = nil
        return
    end
    --继续注册
    driver.insert(handle.timer_id, handle.period)
end

function TimerMgr:on_frame(now_ms)
    if driver then
        local escape_ms = now_ms - self.last_ms + self.escape_ms
        self.escape_ms = escape_ms % TIMER_ACCURYACY
        self.last_ms = now_ms
        if escape_ms >= TIMER_ACCURYACY then
            local timers = driver.update(escape_ms // TIMER_ACCURYACY)
            for _, timer_id in ipairs(timers or {}) do
                local handle = self.timers[timer_id]
                if handle then
                    self:trigger(handle, now_ms)
                end
            end
        end
    end
end

function TimerMgr:once(period, cb, ...)
    return self:register(period, period, 1, cb, ...)
end

function TimerMgr:loop(period, cb, ...)
    return self:register(period, period, -1, cb, ...)
end

function TimerMgr:register(interval, period, times, cb, ...)
    --生成id并注册
    local now_ms = ltime()
    local timer_id = new_guid(period, interval)
    --矫正时间误差
    interval = interval + (now_ms - self.last_ms)
    driver.insert(timer_id, interval // TIMER_ACCURYACY)
    --包装回调参数
    local params = tpack(...)
    params[#params + 1] = 0
    --保存信息
    self.timers[timer_id] = {
        cb = cb,
        last = now_ms,
        times = times,
        params = params,
        timer_id = timer_id,
        period = period // TIMER_ACCURYACY
    }
    return timer_id
end

function TimerMgr:unregister(timer_id)
    self.timers[timer_id] = nil
end

function TimerMgr:on_quit()
    self.timers = {}
    driver = nil
end

quanta.timer_mgr = TimerMgr()

return TimerMgr

```