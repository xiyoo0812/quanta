--log_test.lua
local llog = require("lualog")

llog.init("./newlog/", "qtest", 0, 500000)

llog.debug("aaaaaaaaaa")
llog.info("bbbb")
llog.warn("cccccc")
llog.dump("dddddddddd")
llog.error("eeeeeeeeeeee")

--os.exit()
