--log_test.lua

local LOG_LEVEL     = log.LOG_LEVEL

log.option("./newlog/", "qtest", 1, 1);
log.set_max_line(500000);
log.daemon(true)

log.is_filter(LOG_LEVEL.DEBUG)
log.filter(LOG_LEVEL.DEBUG)

log.add_dest("qtest");
log.add_lvl_dest(LOG_LEVEL.ERROR)

log.debug("aaaaaaaaaa")
log.info("bbbb")
log.warn("cccccc")
log.dump("dddddddddd")
log.error("eeeeeeeeeeee")

--os.exit()
