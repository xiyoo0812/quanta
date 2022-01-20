--log_test.lua
require("lualog")
local GrayLog   = import("driver/graylog.lua")

local ltimer    = require("ltimer")
local lnow_ms   = ltimer.now_ms
local log_info  = logger.info

local timer_mgr = quanta.get("timer_mgr")

local function logger_test(cycle)
    local t1 = lnow_ms()
    for i = 1, cycle do
        log_info("logger_test : now output logger cycle : %d", i)
    end
    local t2 = lnow_ms()
    return t2 - t1
end

local params = { 1, 2, }
for _, cycle in ipairs(params) do
    local time = logger_test(cycle)
    print(string.format("logger_test: cycle %d use time %s ms!", cycle, time))
end

print("logger test end")

local host = "127.0.0.1"

local glog1 = GrayLog("9.134.163.87:8081/tcp")
timer_mgr:register(2000, 1000, 2, function()
    print("GrayLog tcp test:" .. quanta.now)
    glog1:write(host, quanta.id, "logger tcp test" .. quanta.now, 1)
end)

local glog2 = GrayLog("9.134.163.87:8080/http")
timer_mgr:register(2000, 1000, 2, function()
    print("GrayLog http test:" .. quanta.now)
    glog2:write(host, quanta.id, "logger http test" .. quanta.now, 2)
end)

local glog3 = GrayLog("9.134.163.87:8081/udp")
timer_mgr:register(2000, 1000, 2, function()
    print("GrayLog udp test:" .. quanta.now)
    glog3:write(host, quanta.id, "logger udp test" .. quanta.now, 2)
end)

--os.exit()
