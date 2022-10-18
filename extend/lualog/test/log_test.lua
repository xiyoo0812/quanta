--log_test.lua
local llog = require("lualog")

local LOG_LEVEL     = llog.LOG_LEVEL

llog.option("./newlog/", "qtest", 1, 1);
llog.set_max_line(500000);
llog.daemon(true)

llog.is_filter(LOG_LEVEL.DEBUG)
llog.filter(LOG_LEVEL.DEBUG)

llog.add_dest("qtest");
llog.add_lvl_dest(LOG_LEVEL.ERROR)

llog.debug("aaaaaaaaaa")
llog.info("bbbb")
llog.warn("cccccc")
llog.dump("dddddddddd")
llog.error("eeeeeeeeeeee")

--os.exit()
