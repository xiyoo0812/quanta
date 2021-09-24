--log_test.lua
require("lualog")

local logger = quanta.logger

print(logger, type(logger))

logger:debug("aaaaaaaaaa")
logger:info("bbbb")
logger:warn("cccccc")
logger:dump("dddddddddd")
logger:error("eeeeeeeeeeee")

--os.exit()
