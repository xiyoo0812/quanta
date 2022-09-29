--graylog_test.lua

local GrayLog   = import("driver/graylog.lua")

local timer_mgr = quanta.get("timer_mgr")

local glog1 = GrayLog("10.96.8.100:8081/tcp")
timer_mgr:register(2000, 1000, 2, function()
    print("GrayLog tcp test:" .. quanta.now)
    glog1:write("logger tcp test" .. quanta.now, 1)
end)

local glog2 = GrayLog("10.96.8.100:8080/http")
timer_mgr:register(2000, 1000, 2, function()
    print("GrayLog http test:" .. quanta.now)
    glog2:write("logger http test" .. quanta.now, 2)
end)

local glog3 = GrayLog("10.96.8.100:8081/udp")
timer_mgr:register(2000, 1000, 2, function()
    print("GrayLog udp test:" .. quanta.now)
    glog3:write("logger udp test" .. quanta.now, 2)
end)

--os.exit()
