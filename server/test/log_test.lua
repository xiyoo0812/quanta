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

local params = { 100000 }
for _, cycle in ipairs(params) do
    local time = logger_test(cycle)
    log_debug("logger_test: cycle {} use time {} ms!", cycle, time)
end

local params2 = { 100000 }
for _, cycle in ipairs(params2) do
    local time = logger_test(cycle)
    log_dump("logger_test: cycle {} use time {} ms!", cycle, time)
end

log_info("logger test end")

--os.exit()
