--log_test.lua

local lnow_ms   = timer.now_ms
local log_info  = logger.info

local log_debug = logfeature.debug("lualog")
local log_dump  = logfeature.dump("bilogs", true)

local function logger_test(cycle)
    local t1 = lnow_ms()
    for i = 1, cycle do
        log_info("logger_test : now output logger cycle : {}", i)
    end
    local t2 = lnow_ms()
    return t2 - t1
end

local params = { 1 }
for _, cycle in ipairs(params) do
    local time = logger_test(cycle)
    log_debug("logger_test: cycle {} use time {} ms!", cycle, time)
end

local params2 = { 1 }
for _, cycle in ipairs(params2) do
    local time = logger_test(cycle)
    log_dump("logger_test: cycle {} use time {} ms!", cycle, time)
end

local count = 100000
local sformat = string.format
local t1 = timer.clock_ms()
for i = 1, count do
    local x = sformat("test_%d, %s, %s", i, "sas", 3.14159)
    if i == 1 then
        log_debug("============1:{}", x)
    end
end
local t2 = timer.clock_ms() - t1
log_debug("tt22:{}", t2)


local lformat = log.format
local t3 = timer.clock_ms()
for i = 1, count do
    local x = lformat("test_{}, {}, {}", i, "sas", 3.14159)
    if i == 1 then
        log_debug("============2:{}", x)
    end
end
local t4 = timer.clock_ms() - t3
log_debug("tt42:{}", t4)

log_info("logger test end")

--os.exit()
