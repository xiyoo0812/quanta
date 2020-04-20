--base.lua

import("common/math.lua")
import("common/table.lua")
import("common/string.lua")
import("common/logger.lua")
import("common/guid.lua")
import("common/class.lua")
import("common/interface.lua")
import("common/property.lua")

local log_err       = logger.err
local dtraceback    = debug.traceback
local Listener      = import("common/listener.lua")

--函数装饰器: 保护性的调用指定函数,如果出错则写日志
--主要用于一些C回调函数,它们本身不写错误日志
--通过这个装饰器,方便查错
function quanta.xpcall(func, format, ...)
    local ok, err = xpcall(func, dtraceback, ...)
    if not ok then
        log_err(format, err)
        listener:notify_trigger("report_feishu", "代码异常", err)
    end
end

--系统扩展函数名字空间
lua_extend      = lua_extend or {}
--quanta全局变量名字空间
quanta_const    = quanta_const or {}

--创建全局监听器
quanta.listener = Listener()
