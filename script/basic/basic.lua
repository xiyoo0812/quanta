--basic.lua

--系统扩展函数名字空间
math_ext    = math_ext or {}
table_ext   = table_ext or {}
string_ext  = string_ext or {}

--加载basic文件
import("basic/math.lua")
import("basic/table.lua")
import("basic/string.lua")
import("basic/logger.lua")
import("basic/guid.lua")
import("basic/enum.lua")
import("basic/class.lua")
import("basic/interface.lua")
import("basic/property.lua")
import("basic/config/config_mgr.lua")

local log_err       = logger.err
local dtraceback    = debug.traceback
local Listener      = import("basic/listener.lua")

--函数装饰器: 保护性的调用指定函数,如果出错则写日志
--主要用于一些C回调函数,它们本身不写错误日志
--通过这个装饰器,方便查错
function quanta.xpcall(func, format, ...)
    local ok, err = xpcall(func, dtraceback, ...)
    if not ok then
        log_err(format, err)
        listener:notify_trigger("on_feishu_log", "代码异常", err)
    end
end

--quanta全局变量名字空间
quanta_const    = quanta_const or {}

--创建全局监听器
quanta.event_mgr = Listener()
