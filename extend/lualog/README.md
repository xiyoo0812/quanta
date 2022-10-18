# lualog
c++和lua通用的多线程日志库

# 依赖
- c++17
- [lua](https://github.com/xiyoo0812/lua.git)5.2以上
- [luakit](https://github.com/xiyoo0812/luakit.git)一个luabind库
- 项目路径如下<br>
  |--proj <br>
  &emsp;|--lua <br>
  &emsp;|--lualog <br>
  &emsp;|--luakit <br>

# 编译
- msvc : 准备好lua依赖库并放到指定位置，将proj文件加到sln后编译。
- linux：准备好lua依赖库并放到指定位置，执行make -f lualog.mak

# 注意事项
- mimalloc: 参考[quanta](https://github.com/xiyoo0812/quanta.git)使用，不用则在工程文件中注释

# 功能
- 支持C++和lua使用
- 多线程日志输出
- 日志定时滚动输出
- 日志最大行数滚动输出
- 日志分级、分文件输出

# lua使用方法
```lua
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

```

# C++使用方法
```c++
#include "logger.h"

auto logger = logger::log_service::instance();
logger->option("./newlog/", "qtest", 1, logger::rolling_type::DAYLY)
logger->set_max_line(500000);

logger->is_filter(logger::log_level::DEBUG)
logger->filter(logger::log_level::DEBUG)

logger->add_dest("qtest");
logger->add_lvl_dest(logger::log_level::DEBUG);

//异步多线程
logger->start();
LOG_DEBUG << "aaaaaaaaaa";
LOG_WARN << "bbbb";
LOG_INFO << "cccccc";
LOG_ERROR << "dddddddddd";
LOG_FETAL << "eeeeeeeeeeee";

//同步日志输出
logger->terminal();
PRINT_DEBUG << "aaaaaaaaaa";
PRINT_WARN << "bbbb";
PRINT_INFO << "cccccc";
PRINT_ERROR << "dddddddddd";
PRINT_FETAL << "eeeeeeeeeeee";

```
