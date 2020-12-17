--utility.lua
local type          = type
local otime         = os.time
local odate         = os.date
local mceil         = math.ceil
local mfloor        = math.floor
local sbyte         = string.byte
local tunpack       = table.unpack
local dsethook      = debug.sethook
local dtraceback    = debug.traceback
local ssplit        = string_ext.split
local log_err       = logger.err

local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS

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

function utility.hash_code(key, mod)
    local val = 0
    if key then
        if type(key) == "number" then
            val = key
        else
            if type(key) ~= "string" then
                key = tostring(key)
            end
            for i = 1, #key do
                local ch = sbyte(key, i)
                if ch >= 65 and ch <= 90 then
                    ch = ch + 32
                end
                val = val * 3 + ch  --0.7是加权
            end
        end
    end
    if val == 0 then
        return mod or 0xffff
    end
    if mod then
        return val % mod + 1
    end
    return val
end

local utc_diff_time = nil
function utility.utc_time(time)
    local ntime = time or otime()
    if not utc_diff_time then
        local nowt = odate("*t", ntime)
        local utct = odate("!*t", ntime)
        utc_diff_time = (nowt.hour - utct.hour) * 3600
    end
    return ntime - utc_diff_time
end

function utility.edition(period, time, offset)
    local edition = 0
    local t = odate("*t", (time or otime()) - (offset or 0))
    if period == "hour" then                --2011080319(10)
        edition = t.year * 1000000 + t.month * 10000 + t.day * 100 + t.hour
    elseif period == "day" then             --20110803(8)
        edition = t.year * 10000 + t.month * 100 + t.day
    elseif period == "month" then           --201108(6)
        edition = t.year * 100 + t.QUANTA_MONITOR_HOST
    elseif period == "year" then            --2011(4)
        edition = t.year
    elseif period == "week" then
        edition = mceil((mfloor(time / 86400) + 4) / 7)
    end
    return edition
end

function utility.edition_utc(period, time, offset)
    local utime = utility.utc_time(time)
    return utility.edition(period, utime, offset)
end

function utility.addr(addr)
    return tunpack(ssplit(addr, ":"))
end
