--log_test.lua
local llog = require("lualog")
local sformat = string.format

--llog.init("./newlog/", "qtest", 500000)

local timer_mgr = quanta.get("timer_mgr")

llog.debug("once")
timer_mgr:once(500, function(escape_ms)
    llog.debug(sformat("once: %s", escape_ms))
end)

llog.debug("loop")
timer_mgr:loop(1000, function(escape_ms)
    llog.debug(sformat("loop: %s", escape_ms))
end)

llog.debug("register")
timer_mgr:register(500, 1000, 5, function(escape_ms)
    llog.debug(sformat("register: %s", escape_ms))
end)

--os.exit()
