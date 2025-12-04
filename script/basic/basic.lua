--basic.lua
----------------------------------------------
--加载基础功能
import("enum.lua")
import("class.lua")
import("mixin.lua")
import("storage.lua")
import("property.lua")
import("constant.lua")
--加载基础模块
import("basic/math.lua")
import("basic/time.lua")
import("basic/table.lua")
import("basic/string.lua")
import("basic/trace.lua")
import("basic/environ.lua")
import("basic/logger.lua")
import("basic/profile.lua")
import("basic/signal.lua")
import("basic/console.lua")
import("basic/service.lua")

local xpcall        = xpcall
local otime         = os.time
local log_err       = logger.err
local log_fatal     = logger.fatal
local dgetinfo      = debug.getinfo
local dsethook      = debug.sethook
local dtraceback    = debug.traceback

local FAILED        = enum("KernCode").FAILED
local SUCCESS       = enum("KernCode").SUCCESS

local MQ_DRIVER     = environ.get("QUANTA_MQ_DRIVER", "redis")

--函数装饰器: 保护性的调用指定函数,如果出错则写日志
--主要用于一些C回调函数,它们本身不写错误日志
--通过这个装饰器,方便查错
function quanta.xpcall(func, fmt, ...)
    local ok, err = xpcall(func, dtraceback, ...)
    if not ok then
        log_fatal(fmt, err)
    end
    return ok, err
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

function quanta.success(code, ok)
    if ok == nil then
        return code == SUCCESS
    end
    return ok and code == SUCCESS
end

function quanta.failed(code, ok, def_code)
    if ok == nil then
        return code ~= SUCCESS, code or (def_code or FAILED)
    end
    return not ok or code ~= SUCCESS, code or (def_code or FAILED)
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

function quanta.make_mq()
    local Driver
    if MQ_DRIVER == "redis" then
        Driver = import("queue/redis_mq.lua")
    else
        Driver = import("queue/mongo_mq.lua")
    end
    return Driver()
end

function quanta.synclock(key)
    local SyncLock = import("feature/sync_lock.lua")
    return SyncLock(key)
end

function quanta.defer(handler)
    local Defer = import("feature/defer.lua")
    return Defer(handler)
end

--创建仿函数
function quanta.make_functer(func, reenter)
    local Functer = import("feature/functor.lua")
    return Functer(func, reenter)
end

function quanta.http_client(version)
    local HttpClient = import("network/http_client.lua")
    return HttpClient(version)
end

function quanta.grpc_client(addr)
    local GrpcClient = import("network/grpc_client.lua")
    return GrpcClient(addr)
end

function quanta.etcd(addr)
    local Etcd = import("driver/etcd.lua")
    return Etcd(addr)
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
