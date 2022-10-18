--quanta.lua
local logger        = require("lualog")

local xpcall        = xpcall
local otime         = os.time
local log_err       = logger.error
local sformat       = string.format
local dgetinfo      = debug.getinfo
local dsethook      = debug.sethook
local dtraceback    = debug.traceback

--函数装饰器: 保护性的调用指定函数,如果出错则写日志
--主要用于一些C回调函数,它们本身不写错误日志
--通过这个装饰器,方便查错
function quanta.xpcall(func, format, ...)
    local ok, err = xpcall(func, dtraceback, ...)
    if not ok then
        log_err(format, err)
    end
end

function quanta.try_call(func, time, ...)
    while time > 0 do
        time = time - 1
        if func(...) then
            return true
        end
    end
    return false
end

-- 启动死循环监控
function quanta.check_endless_loop()
    local debug_hook = function()
        local now = otime()
        if now - quanta.now >= 10 then
            log_err("check_endless_loop:%s", dtraceback())
        end
    end
    dsethook(debug_hook, "l")
end

function quanta.load(name)
    return quanta[name]
end

function quanta.get(name)
    local global_obj = quanta[name]
    if not global_obj then
        local info = dgetinfo(2, "S")
        log_err(sformat("[quanta][get] %s not initial! source(%s:%s)", name, info.short_src, info.linedefined))
        return
    end
    return global_obj
end

--快速获取enum
function quanta.enum(ename, ekey)
    local eobj = enum(ename)
    if not eobj then
        local info = dgetinfo(2, "S")
        log_err("[quanta][enum] %s not initial! source(%s:%s)", ename, info.short_src, info.linedefined)
        return
    end
    local eval = eobj[ekey]
    if not eval then
        local info = dgetinfo(2, "S")
        log_err("[quanta][enum] %s.%s not defined! source(%s:%s)", ename, ekey, info.short_src, info.linedefined)
        return
    end
    return eval
end