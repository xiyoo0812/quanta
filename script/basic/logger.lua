--logger.lua
--logger功能支持
local llog          = require("lualog")
local lbuffer       = require("lbuffer")

local pcall         = pcall
local ipairs        = ipairs
local sformat       = string.format
local dgetinfo      = debug.getinfo
local tpack         = table.pack
local tunpack       = table.unpack
local lfilter       = llog.filter
local is_filter     = llog.is_filter
local lserialize    = lbuffer.serialize

logger = {}
function logger.init(max_line)
    local log_name  = sformat("%s-%d", quanta.service, quanta.index)
    local log_path = sformat("%s/%s/", environ.get("QUANTA_LOG_PATH"), quanta.service)
    llog.init(log_path, log_name, 0, max_line or 100000)
    logger.filter(environ.number("QUANTA_LOG_LVL"))
    if environ.status("QUANTA_DAEMON") then
        quanta.daemon()
    end
end

logger.close = llog.close

function logger.filter(level)
    for lvl = LOG_LEVEL.DEBUG, LOG_LEVEL.FATAL do
        --llog.filter(level, on/off)
        lfilter(lvl, lvl >= level)
    end
end

local function logger_output(method, fmt, extend, swline, ...)
    if extend then
        local args = tpack(...)
        for i, arg in ipairs(args) do
            if (type(arg) == "table") then
                args[i] = lserialize(arg, swline and 1 or 0)
            end
        end
        return method(sformat(fmt, tunpack(args, 1, args.n)))
    end
    return method(sformat(fmt, ...))
end

local LOG_LEVEL_METHOD = {
    [LOG_LEVEL.INFO]    = { "info",  llog.info,  false, false   },
    [LOG_LEVEL.WARN]    = { "warn",  llog.warn,  true,  false   },
    [LOG_LEVEL.DUMP]    = { "dump",  llog.dump,  true,  true    },
    [LOG_LEVEL.DEBUG]   = { "debug", llog.debug, true,  false   },
    [LOG_LEVEL.ERROR]   = { "err",   llog.error, true,  false   },
    [LOG_LEVEL.FATAL]   = { "fatal", llog.fatal, true,  false   }
}
for lvl, conf in pairs(LOG_LEVEL_METHOD) do
    local name, method, extend, swline = tunpack(conf)
    logger[name] = function(fmt, ...)
        if is_filter(lvl) then
            return false
        end
        local ok, res = pcall(logger_output, method, fmt, extend, swline, ...)
        if not ok then
            local info = dgetinfo(2, "S")
            lwarn(sformat("[logger][%s] format failed: %s, source(%s:%s)", name, res, info.short_src, info.linedefined))
            return false
        end
        return res
    end
end
