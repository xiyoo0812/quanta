--log_test.lua
local llog = require("lualog")

--llog.init("./newlog/", "qtest", 500000)

local timer_mgr = quanta.get("timer_mgr")

llog.debug("aaaaaaaaaa")
llog.info("bbbb")
llog.warn("cccccc")
llog.dump("dddddddddd")
llog.error("eeeeeeeeeeee")

--os.exit()
