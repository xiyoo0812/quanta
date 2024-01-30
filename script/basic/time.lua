--quanta.lua

local otime         = os.time
local odate         = os.date
local odtime        = os.difftime

local DAY_S         = enum("PeriodTime").DAY_S
local HOUR_S        = enum("PeriodTime").HOUR_S
local DIFF_TIME     = odtime(otime(), otime(odate("!*t", otime())))
local TIME_ZONE     = DIFF_TIME / 3600

function quanta.timezone()
    return TIME_ZONE
end

--获取一个类型的时间版本号
function quanta.edition(period, time, offset)
    local edition = 0
    if not time or time <= 0 then
        time = quanta.now
    end
    time = time + DIFF_TIME - (offset or 0)
    local t = odate("*t", time)
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

-- 是否同周
function quanta.sweek(t1, t2)
    if quanta.edition("week", t1) == quanta.edition("week", t2) then
        return true
    end
    return false
end

-- 字符串转时间戳(天)
-- 参数说明: 09:30:00
function quanta.dstotime(time)
    local curTime = odate("*t")
    local hour, min, sec = string.match(time, "(%d+):(%d+):(%d+)")
    curTime.hour = hour
    curTime.min = min
    curTime.sec = sec
    local timestamp = os.time(curTime)
    return timestamp
end
