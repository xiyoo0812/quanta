--logger.lua
--logger功能支持
local lcodec        = require("lcodec")
local llogger       = require("lualog")

local pcall         = pcall
local pairs         = pairs
local tpack         = table.pack
local tunpack       = table.unpack
local dgetinfo      = debug.getinfo
local sformat       = string.format
local serialize     = lcodec.serialize
local lwarn         = llogger.warn
local lfilter       = llogger.filter
local lis_filter    = llogger.is_filter

local LOG_LEVEL     = llogger.LOG_LEVEL

local dispatching   = false
local title         = quanta.title
local monitors      = _ENV.monitors or {}

logger = {}
logfeature = {}

function logger.init()
    --配置日志信息
    llogger.set_max_line(environ.number("QUANTA_LOG_LINE", 100000))
    llogger.set_rolling_type(environ.number("QUANTA_LOG_ROLL", 0))
    --设置日志过滤
    logger.filter(environ.number("QUANTA_LOG_LVL"))
    --添加输出目标
    llogger.add_dest(quanta.service_name);
    llogger.add_lvl_dest(LOG_LEVEL.ERROR)
    --设置daemon
    llogger.daemon(environ.status("QUANTA_DAEMON"))
end

function logger.daemon(daemon)
    llogger.daemon(daemon)
end

function logger.add_monitor(monitor, lvl)
    monitors[monitor] = lvl
end

function logger.remove_monitor(monitor)
    monitors[monitor] = nil
end

function logger.filter(level)
    for lvl = LOG_LEVEL.DEBUG, LOG_LEVEL.FATAL do
        --lfilter(level, on/off)
        lfilter(lvl, lvl >= level)
    end
end

local function logger_output(feature, notify, lvl, lvl_name, fmt, log_conf, ...)
    if lis_filter(lvl) then
        return
    end
    local content
    local lvl_func, extend, swline = tunpack(log_conf)
    if extend then
        local args = tpack(...)
        for i, arg in pairs(args) do
            if type(arg) == "table" then
                args[i] = serialize(arg, swline and 1 or 0)
            end
        end
        content = sformat(fmt, tunpack(args, 1, args.n))
    else
        content = sformat(fmt, ...)
    end
    lvl_func(content, title, feature)
    if notify and not dispatching then
        --防止重入
        dispatching = true
        for monitor, mlvl in pairs(monitors) do
            if lvl >= mlvl then
                monitor:dispatch_log(content, lvl_name)
            end
        end
        dispatching = false
    end
end

local LOG_LEVEL_OPTIONS = {
    [LOG_LEVEL.INFO]    = { "info",  { llogger.info,  false, false } },
    [LOG_LEVEL.WARN]    = { "warn",  { llogger.warn,  true,  false } },
    [LOG_LEVEL.DUMP]    = { "dump",  { llogger.dump,  true,  true  } },
    [LOG_LEVEL.DEBUG]   = { "debug", { llogger.debug, true,  false } },
    [LOG_LEVEL.ERROR]   = { "err",   { llogger.error, true,  false } },
    [LOG_LEVEL.FATAL]   = { "fatal", { llogger.fatal, true,  false } }
}
for lvl, conf in pairs(LOG_LEVEL_OPTIONS) do
    local lvl_name, log_conf = tunpack(conf)
    logger[lvl_name] = function(fmt, ...)
        local ok, res = pcall(logger_output, "", true, lvl, lvl_name, fmt, log_conf, ...)
        if not ok then
            local info = dgetinfo(2, "S")
            lwarn(sformat("[logger][%s] format failed: %s, source(%s:%s)", lvl_name, res, info.short_src, info.linedefined))
            return false
        end
        return res
    end
end

for lvl, conf in pairs(LOG_LEVEL_OPTIONS) do
    local lvl_name, log_conf = tunpack(conf)
    logfeature[lvl_name] = function(feature, path, prefix)
        llogger.add_dest(feature, path)
        llogger.ignore_prefix(feature, prefix)
        return function(fmt, ...)
            local ok, res = pcall(logger_output, feature, false, lvl, lvl_name, fmt, log_conf, ...)
            if not ok then
                local info = dgetinfo(2, "S")
                lwarn(sformat("[logfeature][%s] format failed: %s, source(%s:%s)", lvl_name, res, info.short_src, info.linedefined))
                return false
            end
            return res
        end
    end
end