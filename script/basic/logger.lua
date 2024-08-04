--logger.lua
--logger功能支持

local pcall         = pcall
local pairs         = pairs
local tunpack       = table.unpack
local dtraceback    = debug.traceback
local lprint        = log.print
local lfilter       = log.filter

local LOG_FLAG      = log.LOG_FLAG
local LOG_LEVEL     = log.LOG_LEVEL

local title         = quanta.title
local MONITORS      = quanta.init("MONITORS")

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

function logger.add_monitor(monitor, level)
    local lvl = level or LOG_LEVEL.FATAL
    if not MONITORS[lvl] then
        MONITORS[lvl] = {[monitor] = true}
        return
    end
    MONITORS[lvl][monitor] = true
end

function logger.remove_monitor(monitor, level)
    local lvl = level or LOG_LEVEL.FATAL
    if MONITORS[lvl] then
        MONITORS[lvl][monitor] = nil
        if not next(MONITORS[lvl]) then
            MONITORS[lvl] = nil
        end
    end
end

function logger.filter(level)
    for lvl = LOG_LEVEL.DEBUG, LOG_LEVEL.FATAL do
        --lfilter(level, on/off)
        lfilter(lvl, lvl >= level)
    end
end

local function logger_output(flag, feature, lvl, lvl_name, fmt, ...)
    local monitors = MONITORS[lvl]
    if monitors then
        flag = flag | LOG_FLAG.MONITOR
    end
    local ok, msg = pcall(lprint, lvl, flag, title, feature, fmt, ...)
    if not ok then
        local wfmt = "[logger][{}] format failed: {}=> {})"
        lprint(LOG_LEVEL.WARN, 0, title, feature, wfmt, lvl_name, msg, dtraceback())
        return
    end
    if msg then
        for monitor in pairs(monitors) do
            monitor:dispatch_log(msg, lvl_name)
        end
    end
end

local LOG_LEVEL_OPTIONS = {
    [LOG_LEVEL.INFO]    = { "info",  LOG_FLAG.NULL },
    [LOG_LEVEL.WARN]    = { "warn",  LOG_FLAG.FORMAT },
    [LOG_LEVEL.DEBUG]   = { "debug", LOG_FLAG.FORMAT },
    [LOG_LEVEL.ERROR]   = { "err",   LOG_FLAG.FORMAT },
    [LOG_LEVEL.FATAL]   = { "fatal", LOG_FLAG.FORMAT },
    [LOG_LEVEL.DUMP]    = { "dump",  LOG_FLAG.FORMAT | LOG_FLAG.PRETTY },
}

for lvl, conf in pairs(LOG_LEVEL_OPTIONS) do
    local lvl_name, flag = tunpack(conf)
    logger[lvl_name] = function(fmt, ...)
        logger_output(flag, "", lvl, lvl_name, fmt, ...)
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
