--utility.lua
local type          = type
local otime         = os.time
local odate         = os.date
local log_err       = logger.err
local sbyte         = string.byte
local tunpack       = table.unpack
local dsethook      = debug.sethook
local dtraceback    = debug.traceback
local ssplit        = string_ext.split

local KernCode      = enum("KernCode")
local PeriodTime    = enum("PeriodTime")
local SUCCESS       = KernCode.SUCCESS
local DAY_S         = PeriodTime.DAY_S

utility = {}
function utility.check_success(code)
    return code == SUCCESS
end

function utility.check_failed(code)
    return code ~= SUCCESS
end

-- 启动死循环监控
local check_close_loop = true
function utility.check_endless_loop()
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

--获取utc时间戳
local utc_diff_time = nil
function utility.utc_time(time)
    if not time or time <= 0 then
        time = quanta.now
    end
    if not utc_diff_time then
        local nowt = odate("*t", time)
        local utct = odate("!*t", time)
        utc_diff_time = (nowt.hour - utct.hour) * PeriodTime.HOUR_S
    end
    return time - utc_diff_time
end

--获取一个类型的时间版本号
function utility.edition(period, time, offset)
    local edition = 0
    if not time or time <= 0 then
        time = quanta.now
    end
    local t = odate("*t", time - (offset or 0))
    if period == "hour" then
        edition = time // PeriodTime.HOUR_S
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
function utility.edition_utc(period, time, offset)
    local utime = utility.utc_time(time)
    return utility.edition(period, utime, offset)
end

--解析ip地址
function utility.addr(addr)
    return tunpack(ssplit(addr, ":"))
end
