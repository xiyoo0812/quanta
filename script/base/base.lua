--base.lua

import("base/math.lua")
import("base/table.lua")
import("base/string.lua")
import("base/logger.lua")
import("base/guid.lua")
import("base/enum.lua")
import("base/class.lua")
import("base/interface.lua")
import("base/property.lua")

local log_err       = logger.err
local dtraceback    = debug.traceback
local Listener      = import("base/listener.lua")

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
math_ext    = math_ext or {}
table_ext   = table_ext or {}
string_ext  = string_ext or {}
--quanta全局变量名字空间
quanta_const    = quanta_const or {}

--创建全局监听器
quanta.listener = Listener()
