--timer_test.lua

local log_info  = logger.info
local Timer     = import("feature/timer.lua")

local msec, sec = timer.time()
log_info("time: sec:{}, msec:{}", sec, msec)
--timer:sleep(2000)
local tm = os.time()
local now = timer.now()
local now_ms = timer.now_ms()
log_info("time: tm:{}, now:{}, now_ms:{}", tm, now, now_ms)

local clock = timer.clock()
local clock_ms = timer.clock_ms()
log_info("time: clock:{}, clock_ms:{}", clock, clock_ms)

local timer_mgr = quanta.get("timer_mgr")
local thread_mgr = quanta.get("thread_mgr")

thread_mgr:fork(function()
    local timer_once = timer_mgr:once(500, function(escape_ms, arg)
        log_info("once: escape_ms {}, arg = {}", escape_ms, arg)
    end, 3)
    log_info("once test: {}", timer_once)

    local timer_loop = timer_mgr:loop(1000, function(escape_ms)
        log_info("loop: escape_ms {}", escape_ms)
    end)
    log_info("loop test: {}", timer_loop)

    local timer_register = timer_mgr:register(500, 1000, 5, function(escape_ms)
        log_info("register: {}", escape_ms)
    end)
    log_info("register test: {}", timer_register)

    local ttimer1 = Timer()
    ttimer1:once(1000, function(escape_ms)
        log_info("ttimer once=====: {}", escape_ms)
    end)
    local ttimer2 = Timer()
    ttimer2:loop(1000, function(escape_ms)
        log_info("ttimer loop=====: {}", escape_ms)
    end)
    local time = 1
    local ttimer3 = Timer()
    ttimer3:register(500, 1000, 10, function(escape_ms)
        log_info("ttimer register=====: {}", escape_ms)
        time = time + 1
        if time == 3 then
            log_info("ttimer change_period 2000")
            timer_mgr:change_period(timer_loop, 2000)
            quanta.ttimer2:change_period(2000)
        end
        if time == 5 then
            log_info("ttimer collectgarbage local: {}", time)
            collectgarbage()
        end
        if time == 8 then
            quanta.ttimer2 = nil
            quanta.ttimer3 = nil
            log_info("ttimer collectgarbage global: {}", time)
            collectgarbage()
        end
    end)
    quanta.ttimer2 = ttimer2
    quanta.ttimer3 = ttimer3
end)

--os.exit()
