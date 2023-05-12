--basic.lua
----------------------------------------------
---加载基础模块
import("basic/math.lua")
import("basic/table.lua")
import("basic/string.lua")
import("basic/logger.lua")
import("basic/signal.lua")
import("basic/environ.lua")
--加载基础功能
import("enum.lua")
import("class.lua")
import("mixin.lua")
import("property.lua")
import("quanta.lua")
import("constant.lua")
import("basic/math.lua")
import("basic/table.lua")
import("basic/string.lua")
import("basic/console.lua")
import("basic/service.lua")

local odate     = os.date
local qenum     = quanta.enum

local FAILED    = qenum("KernCode", "FAILED")
local SUCCESS   = qenum("KernCode", "SUCCESS")
local DAY_S     = qenum("PeriodTime", "DAY_S")
local HOUR_S    = qenum("PeriodTime", "HOUR_S")

function quanta.success(code, ok)
    if ok == nil then
        return code == SUCCESS
    end
    return ok and code == SUCCESS
end

function quanta.failed(code, ok, def_code)
    if ok == nil then
        return code ~= SUCCESS
    end
    return not ok or code ~= SUCCESS, ok and code or (def_code or FAILED)
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
