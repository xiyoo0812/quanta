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
local lserialize    = lbuffer.serialize

local LOG_LEVEL     = llog.LOG_LEVEL

local driver        = quanta.logger

logger = {}
function logger.init(max_line)
    logger.filter(environ.number("QUANTA_LOG_LVL"))
end

function logger.filter(level)
    for lvl = LOG_LEVEL.DEBUG, LOG_LEVEL.FATAL do
        --driver:filter(level, on/off)
        driver:filter(lvl, lvl >= level)
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
        return method(driver, sformat(fmt, tunpack(args, 1, args.n)))
    end
    return method(driver, sformat(fmt, ...))
end

local LOG_LEVEL_METHOD = {
    [LOG_LEVEL.INFO]    = { "info",  driver.info,  false, false   },
    [LOG_LEVEL.WARN]    = { "warn",  driver.warn,  true,  false   },
    [LOG_LEVEL.DUMP]    = { "dump",  driver.dump,  true,  true    },
    [LOG_LEVEL.DEBUG]   = { "debug", driver.debug, true,  false   },
    [LOG_LEVEL.ERROR]   = { "err",   driver.error, true,  false   },
    [LOG_LEVEL.FATAL]   = { "fatal", driver.fatal, true,  false   }
}
for lvl, conf in pairs(LOG_LEVEL_METHOD) do
    local name, method, extend, swline = tunpack(conf)
    logger[name] = function(fmt, ...)
        if driver:is_filter(lvl) then
            return false
        end
        local ok, res = pcall(logger_output, method, fmt, extend, swline, ...)
        if not ok then
            local info = dgetinfo(2, "S")
            driver:warn(sformat("[logger][%s] format failed: %s, source(%s:%s)", name, res, info.short_src, info.linedefined))
            return false
        end
        return res
    end
end
