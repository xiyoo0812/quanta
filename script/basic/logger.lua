--logger.lua
--logger功能支持

local pcall         = pcall
local pairs         = pairs
local tunpack       = table.unpack
local dtraceback    = debug.traceback
local env_number    = environ.number
local cleanbytime   = stdfs.cleanbytime
local qtrace_id     = quanta.trace_id
local lprint        = log.print
local lfilter       = log.filter
local LOG_FLAG      = log.LOG_FLAG
local LOG_LEVEL     = log.LOG_LEVEL

local THREAD_NAME   = quanta.thread

local MONITORS      = quanta.init("MONITORS")

logger = {}
logfeature = {}

function logger.init()
    --配置日志信息
    log.set_max_line(env_number("QUANTA_LOG_LINE"), 100000)
    log.set_rolling_type(env_number("QUANTA_LOG_ROLL"), 0)
    --设置daemon
    log.daemon(environ.status("QUANTA_DAEMON", 0))
    --添加输出目标
    log.add_lvl_dest(LOG_LEVEL.ERROR)
    --设置日志过滤
    local level = env_number("QUANTA_LOG_LVL", LOG_LEVEL.INFO)
    for lvl = LOG_LEVEL.DEBUG, LOG_LEVEL.FATAL do
        log.filter(lvl, lvl >= level)
    end
end

function logger.clean()
    local log_path = environ.get("QUANTA_LOG_PATH")
    local clean_time = env_number("QUANTA_LOG_TIME", 648000)
    cleanbytime(log_path, ".log", clean_time)
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
    local trace_id = qtrace_id()
    local ok, msg = pcall(lprint, lvl, flag, THREAD_NAME, trace_id, feature, fmt, ...)
    if not ok then
        local wfmt = "[logger][{}] format failed: {}=> {})"
        lprint(LOG_LEVEL.WARN, 0, THREAD_NAME, trace_id, feature, wfmt, lvl_name, msg, dtraceback())
        return
    end
    if msg then
        for monitor in pairs(monitors) do
            monitor:collect_log(msg, lvl_name)
        end
    end
end

local LOG_OPTIONS = {
    [LOG_LEVEL.INFO]    = { "info",  LOG_FLAG.NULL, "print" },
    [LOG_LEVEL.WARN]    = { "warn",  LOG_FLAG.FORMAT, "warn" },
    [LOG_LEVEL.ERROR]   = { "err",   LOG_FLAG.FORMAT, "error" },
    [LOG_LEVEL.FATAL]   = { "fatal", LOG_FLAG.FORMAT, "fatal" },
    [LOG_LEVEL.DUMP]    = { "dump",  LOG_FLAG.FORMAT | LOG_FLAG.PRETTY, "dump" },
    [LOG_LEVEL.DEBUG]   = { "debug", LOG_FLAG.FORMAT | LOG_FLAG.PRETTY, "trace" },
}

for lvl, conf in pairs(LOG_OPTIONS) do
    local lvl_name, flag, sysfunc = tunpack(conf)
    logger[lvl_name] = function(fmt, ...)
        logger_output(flag, "", lvl, lvl_name, fmt, ...)
    end
    if sysfunc then
        --替换系统函数
        _G[sysfunc] = logger[lvl_name]
    end
end

for lvl, conf in pairs(LOG_OPTIONS) do
    local lvl_name, flag = tunpack(conf)
    logfeature[lvl_name] = function(feature, ign_prefix)
        log.add_dest(feature)
        log.ignore_prefix(feature, ign_prefix)
        return function(fmt, ...)
            logger_output(flag, feature, lvl, lvl_name, fmt, ...)
        end
    end
end
