-- timer_test.lua
local sformat       = string.format

local timer_mgr     = quanta.get("timer_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local Timer         = import("feature/timer.lua")
local TestCase      = import("test/case.lua")

local TimerTest = class(TestCase)

function TimerTest:on_cleanup()
    for id, handle in pairs(timer_mgr.timers or {}) do
        if handle.tag == "TimerTest" then
            timer_mgr:unregister(id)
        end
    end
end

function TimerTest:run()
    ------------------------------------------------------------------
    --1. 时间函数: 均为数值且单调不减
    ------------------------------------------------------------------
    local now1, now2 = timer.now(), timer.now()
    self:report("now is number", type(now1) == "number", type(now1), "number")
    self:report("now monotonic", now2 >= now1, sformat("{}/{}", now1, now2), "nondecreasing")
    local ms1, ms2 = timer.now_ms(), timer.now_ms()
    self:report("now_ms monotonic", ms2 >= ms1, sformat("{}/{}", ms1, ms2), "nondecreasing")
    local cs1, cs2 = timer.now_cs(), timer.now_cs()
    self:report("now_cs monotonic", cs2 >= cs1, sformat("{}/{}", cs1, cs2), "nondecreasing")
    local clk1, clk2 = timer.clock(), timer.clock()
    self:report("clock monotonic", clk2 >= clk1, sformat("{}/{}", clk1, clk2), "nondecreasing")
    local ckms1, ckms2 = timer.clock_ms(), timer.clock_ms()
    self:report("clock_ms monotonic", ckms2 >= ckms1, sformat("{}/{}", ckms1, ckms2), "nondecreasing")
    local tmsec, tmsteady = timer.time()
    self:report("time returns two numbers", type(tmsec) == "number" and type(tmsteady) == "number",
        sformat("{}/{}", tmsec, tmsteady), "number/number")
    self:report("now_ms ~= clock_ms scale", ms2 > 1000000000, ms2, ">1e9(epoch ms)")

    ------------------------------------------------------------------
    --2. timer_mgr.once: 触发一次, 携带自定义参数, escape_ms 为数值
    ------------------------------------------------------------------
    local once_fired, once_arg, once_escape = 0, nil, nil
    local once_id = timer_mgr:once(100, function(escape_ms, arg)
        once_fired = once_fired + 1
        once_escape = escape_ms
        once_arg = arg
    end, "tag-once")
    self:report("once returns id", type(once_id) == "number" and once_id > 0, once_id, ">0")
    if timer_mgr.timers[once_id] then timer_mgr.timers[once_id].tag = "TimerTest" end
    thread_mgr:sleep(500)
    self:report("once fired once", once_fired == 1, once_fired, 1)
    self:report("once arg passed", once_arg == "tag-once", once_arg, "tag-once")
    self:report("once escape_ms number", type(once_escape) == "number", once_escape, "number")

    ------------------------------------------------------------------
    --3. timer_mgr.loop: 多次触发后 unregister 停止
    ------------------------------------------------------------------
    local loop_count = 0
    local loop_id = timer_mgr:loop(80, function()
        loop_count = loop_count + 1
    end)
    self:report("loop returns id", type(loop_id) == "number" and loop_id > 0, loop_id, ">0")
    if timer_mgr.timers[loop_id] then timer_mgr.timers[loop_id].tag = "TimerTest" end
    thread_mgr:sleep(500)
    self:report("loop fired multiple", loop_count >= 2, loop_count, ">=2")
    local before_stop = loop_count
    timer_mgr:unregister(loop_id)
    thread_mgr:sleep(300)
    self:report("unregister stops loop", loop_count == before_stop, sformat("{}/{}", before_stop, loop_count), "stable")

    ------------------------------------------------------------------
    --4. timer_mgr.register(interval, period, times): 限定次数
    ------------------------------------------------------------------
    local reg_count = 0
    local reg_id = timer_mgr:register(60, 60, 3, function()
        reg_count = reg_count + 1
    end)
    self:report("register returns id", type(reg_id) == "number" and reg_id > 0, reg_id, ">0")
    if timer_mgr.timers[reg_id] then timer_mgr.timers[reg_id].tag = "TimerTest" end
    thread_mgr:sleep(600)
    self:report("register fired 3 times", reg_count == 3, reg_count, 3)

    ------------------------------------------------------------------
    --5. Timer 类封装: once / loop / change_period / unregister
    ------------------------------------------------------------------
    local tobj = Timer()
    local t_fired, t_arg = 0, nil
    tobj:once(120, function(escape_ms, arg)
        t_fired = t_fired + 1
        t_arg = arg
    end, "T-once")
    self:report("Timer.once sets timer_id", type(tobj.timer_id) == "number" and tobj.timer_id > 0, tobj.timer_id, ">0")
    if timer_mgr.timers[tobj.timer_id] then timer_mgr.timers[tobj.timer_id].tag = "TimerTest" end
    thread_mgr:sleep(500)
    self:report("Timer.once fired", t_fired == 1 and t_arg == "T-once", sformat("{}/{}", t_fired, t_arg), "1/T-once")

    local lobj = Timer()
    local l_count = 0
    lobj:loop(200, function() l_count = l_count + 1 end)
    if timer_mgr.timers[lobj.timer_id] then timer_mgr.timers[lobj.timer_id].tag = "TimerTest" end
    lobj:change_period(60)
    thread_mgr:sleep(400)
    self:report("Timer.change_period faster", l_count >= 2, l_count, ">=2")
    lobj:unregister()
    local stopped_at = l_count
    thread_mgr:sleep(250)
    self:report("Timer.unregister stops", l_count == stopped_at, sformat("{}/{}", stopped_at, l_count), "stable")
end

return TimerTest
