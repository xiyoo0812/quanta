--quanta.lua

local xpcall        = xpcall
local otime         = os.time
local log_err       = logger.err
local log_fatal     = logger.fatal
local dgetinfo      = debug.getinfo
local dsethook      = debug.sethook
local dtraceback    = debug.traceback

local MQ_DRIVER     = environ.get("QUANTA_MQ_DRIVER", "redis")

--函数装饰器: 保护性的调用指定函数,如果出错则写日志
--主要用于一些C回调函数,它们本身不写错误日志
--通过这个装饰器,方便查错
function quanta.xpcall(func, fmt, ...)
    local ok, err = xpcall(func, dtraceback, ...)
    if not ok then
        log_fatal(fmt, err)
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
            log_err("check_endless_loop:{}", dtraceback())
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
        log_err("[quanta][get] {} not initial! source({}:{})", name, info.short_src, info.linedefined)
        return
    end
    return global_obj
end

--快速获取enum
function quanta.enum(ename, ekey)
    local eobj = enum(ename)
    if not eobj then
        local info = dgetinfo(2, "S")
        log_err("[quanta][enum] {} not initial! source({}:{})", ename, info.short_src, info.linedefined)
        return
    end
    local eval = eobj[ekey]
    if not eval then
        local info = dgetinfo(2, "S")
        log_err("[quanta][enum] {}.{} not defined! source({}:{})", ename, ekey, info.short_src, info.linedefined)
        return
    end
    return eval
end

function quanta.create(name, pclass)
    if not quanta[name] then
        quanta[name] = pclass()
    end
end

function quanta.make_mq()
    local Driver
    if MQ_DRIVER == "redis" then
        Driver = import("queue/redis_mq.lua")
    else
        Driver = import("queue/mongo_mq.lua")
    end
    return Driver()
end

function quanta.defer(handler)
    local Defer = import("feature/defer.lua")
    return Defer(handler)
end

--创建普通计数器
function quanta.make_counter(title)
    local Counter = import("feature/counter.lua")
    return Counter(title)
end

--创建采样计数器
function quanta.make_sampling(title, period)
    local Counter = import("feature/counter.lua")
    local counter = Counter(title)
    counter:sampling(period)
    return counter
end

--创建管道
function quanta.make_channel(title)
    local Channel = import("feature/channel.lua")
    return Channel(title)
end

--创建定时器
function quanta.make_timer()
    local Timer = import("feature/timer.lua")
    return Timer()
end
