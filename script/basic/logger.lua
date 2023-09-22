--logger.lua
--logger功能支持

local pcall         = pcall
local pairs         = pairs
local tunpack       = table.unpack
local dgetinfo      = debug.getinfo
local sformat       = string.format
local lprint        = log.print
local lfilter       = log.filter

local LOG_LEVEL     = log.LOG_LEVEL

local title         = quanta.title
local monitors      = _ENV.monitors or {}

logger = {}
logfeature = {}

function logger.init()
    --配置日志信息
    log.set_max_line(environ.number("QUANTA_LOG_LINE", 100000))
    log.set_clean_time(environ.number("QUANTA_LOG_TIME", 648000))
    log.set_rolling_type(environ.number("QUANTA_LOG_ROLL", 0))
    --设置日志过滤
    logger.filter(environ.number("QUANTA_LOG_LVL"))
    --添加输出目标
    log.add_dest(quanta.service_name);
    log.add_lvl_dest(LOG_LEVEL.ERROR)
    --设置daemon
    log.daemon(environ.status("QUANTA_DAEMON"))
end

function logger.daemon(daemon)
    log.daemon(daemon)
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

local function logger_format(flag, feature, lvl, lvl_name, fmt, ...)
    local ok, msg = pcall(sformat, fmt, ...)
    if not ok then
        local info = dgetinfo(4, "S")
        local wfmt = "[logger][{}] format failed: {}, source({}:{})"
        lprint(LOG_LEVEL.WARN, 0, title, feature, wfmt, lvl_name, msg, info.short_src, info.linedefined)
        return
    end
    lprint(lvl, flag, title, feature, msg)
end

local function logger_output(flag, feature, lvl, lvl_name, fmt, ...)
    if not fmt:find("{") then
        return logger_format(flag, feature, lvl, lvl_name, fmt, ...)
    end
    local ok, msg = pcall(lprint, lvl, flag, title, feature, fmt, ...)
    if not ok then
        local info = dgetinfo(3, "S")
        local wfmt = "[logger][{}] format failed: {}, source({}:{})"
        lprint(LOG_LEVEL.WARN, 0, title, feature, wfmt, lvl_name, msg, info.short_src, info.linedefined)
        return
    end
    return msg
end

local LOG_LEVEL_OPTIONS = {
    [LOG_LEVEL.INFO]    = { "info",  0x00 },
    [LOG_LEVEL.WARN]    = { "warn",  0x01 },
    [LOG_LEVEL.DEBUG]   = { "debug", 0x01 },
    [LOG_LEVEL.ERROR]   = { "err",   0x01 },
    [LOG_LEVEL.FATAL]   = { "fatal", 0x01 },
    [LOG_LEVEL.DUMP]    = { "dump",  0x01 | 0x02 },
}
for lvl, conf in pairs(LOG_LEVEL_OPTIONS) do
    local lvl_name, flag = tunpack(conf)
    logger[lvl_name] = function(fmt, ...)
        local msg = logger_output(flag, "", lvl, lvl_name, fmt, ...)
        if msg then
            for monitor in pairs(monitors) do
                monitor:dispatch_log(msg, lvl_name)
            end
        end
    end
end

for lvl, conf in pairs(LOG_LEVEL_OPTIONS) do
    local lvl_name, flag = tunpack(conf)
    logfeature[lvl_name] = function(feature, path, prefix, clean_time)
        log.add_dest(feature, path)
        log.ignore_prefix(feature, prefix)
        if clean_time then
            log.set_dest_clean_time(feature, clean_time)
        end
        return function(fmt, ...)
            logger_output(flag, feature, lvl, lvl_name, fmt, ...)
        end
    end
end