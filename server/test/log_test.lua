--log_test.lua
require("lualog")

local ltimer    = require("ltimer")
local lnow_ms   = ltimer.now_ms
local log_info  = logger.info


local function logger_test(cycle)
    local t1 = lnow_ms()
    for i = 1, cycle do
        log_info("logger_test : now output logger cycle : %d", i)
    end
    local t2 = lnow_ms()
    return t2 - t1
end

local params = { 1000, 5000, }
for _, cycle in ipairs(params) do
    local time = logger_test(cycle)
    print(string.format("logger_test: cycle %d use time %s ms!", cycle, time))
end

print("logger test end")

--os.exit()
