--basic.lua
import("enum.lua")
import("class.lua")
import("mixin.lua")
import("property.lua")
import("constant.lua")
import("basic/math.lua")
import("basic/table.lua")
import("basic/string.lua")
import("basic/logger.lua")
import("basic/signal.lua")
import("basic/environ.lua")
import("basic/console.lua")
import("basic/service.lua")
import("basic/listener.lua")

local otime         = os.time
local odate         = os.date
local log_err       = logger.err
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
local check_close_loop = true
function quanta.check_endless_loop()
    if check_close_loop then
        local debug_hook = function()
            local now = otime()
            if now - quanta.now >= 10 then
                log_err("check_endless_loop:%s", dtraceback())
            end
        end
        dsethook(debug_hook, "l")
    end
end

--快速获取enum
local function qenum(ename, ekey)
    local eobj = enum(ename)
    if not eobj then
        local info = dgetinfo(2, "S")
        log_err(sformat("[quanta][enum] %s not initial! source(%s:%s)", ename, info.short_src, info.linedefined))
        return
    end
    local eval = eobj[ekey]
    if not eval then
        local info = dgetinfo(2, "S")
        log_err(sformat("[quanta][enum] %s.%s not defined! source(%s:%s)", ename, ekey, info.short_src, info.linedefined))
        return
    end
    return eval
end

quanta.enum     = qenum

local SUCCESS   = qenum("KernCode", "SUCCESS")
local DAY_S     = qenum("PeriodTime", "DAY_S")
local HOUR_S    = qenum("PeriodTime", "HOUR_S")

function quanta.success(code)
    return code == SUCCESS
end

function quanta.failed(code)
    return code ~= SUCCESS
end

--获取utc时间戳
local utc_diff_time = nil
function quanta.utc_time(time)
    if not time or time <= 0 then
        time = quanta.now
    end
    if not utc_diff_time then
        local nowt = odate("*t", time)
        local utct = odate("!*t", time)
        utc_diff_time = (nowt.hour - utct.hour) * HOUR_S
    end
    return time - utc_diff_time
end

--获取一个类型的时间版本号
function quanta.edition(period, time, offset)
    local edition = 0
    if not time or time <= 0 then
        time = quanta.now
    end
    local t = odate("*t", time - (offset or 0))
    if period == "hour" then
        edition = time // HOUR_S
    elseif period == "day" then
        edition = time // DAY_S
    elseif period == "week" then
        --19700101是星期四，周日为每周第一天
        edition = ((time // DAY_S) + 4) // 7
    elseif period == "month" then
        edition = t.year * 100 + t.month
    elseif period == "year" then
        edition = t.year
    end
    return edition
end

--获取UTC的时间版本号
function quanta.edition_utc(period, time, offset)
    local utime = quanta.utc_time(time)
    return quanta.edition(period, utime, offset)
end
