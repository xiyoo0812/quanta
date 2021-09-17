--log_test.lua
local ltimer    = require("ltimer")

local log_info  = logger.info
local sformat   = string.format

local msec, sec = ltimer.time()
log_info("time: sec:%s, msec:%s", sec, msec)
--ltimer:sleep(2000)
local now = ltimer.now()
local now_ms = ltimer.now_ms()
log_info("time: now:%s, now_ms:%s", now, now_ms)

local steady = ltimer.steady()
local steady_ms = ltimer.steady_ms()
log_info("time: steady:%s, steady_ms:%s", steady, steady_ms)

local timer_mgr = quanta.get("timer_mgr")

log_info("once")
timer_mgr:once(500, function(escape_ms)
    log_info(sformat("once: %s", escape_ms))
end)

log_info("loop")
timer_mgr:loop(1000, function(escape_ms)
    log_info(sformat("loop: %s", escape_ms))
end)

log_info("register")
timer_mgr:register(500, 1000, 5, function(escape_ms)
    log_info(sformat("register: %s", escape_ms))
end)

--os.exit()
