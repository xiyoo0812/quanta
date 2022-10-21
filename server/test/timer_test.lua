--log_test.lua
local ltimer    = require("ltimer")

local qget      = quanta.get
local log_info  = logger.info

local msec, sec = ltimer.time()
log_info("time: sec:%s, msec:%s", sec, msec)
--ltimer:sleep(2000)
local now = ltimer.now()
local now_ms = ltimer.now_ms()
log_info("time: now:%s, now_ms:%s", now, now_ms)

local clock = ltimer.clock()
local clock_ms = ltimer.clock_ms()
log_info("time: clock:%s, clock_ms:%s", clock, clock_ms)

local timer_mgr = qget("timer_mgr")
local thread_mgr = qget("thread_mgr")

thread_mgr:fork(function()
    log_info("once")
    timer_mgr:once(500, function(escape_ms)
        log_info("once: %s", escape_ms)
    end, 3)

    log_info("loop")
    timer_mgr:loop(1000, function(escape_ms)
        log_info("loop: %s", escape_ms)
    end)

    log_info("register")
    timer_mgr:register(500, 1000, 5, function(escape_ms)
        log_info("register: %s", escape_ms)
    end)
end)

--os.exit()
