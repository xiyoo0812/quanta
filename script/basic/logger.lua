--logger.lua
--logger功能支持
local llog          = require("lualog")
local lbuffer       = require("lbuffer")

local pcall         = pcall
local ipairs        = ipairs
local stdout        = io.stdout
local ssub          = string.sub
local schar         = string.char
local sformat       = string.format
local dgetinfo      = debug.getinfo
local tpack         = table.pack
local tunpack       = table.unpack
local tconcat       = table.concat
local is_filter     = llog.is_filter
local lserialize    = lbuffer.serialize

local LOG_LEVEL_DEBUG   = 1
local LOG_LEVEL_INFO    = 2
local LOG_LEVEL_WARN    = 3
local LOG_LEVEL_DUMP    = 4
local LOG_LEVEL_ERROR   = 5
local LOG_LEVEL_FATAL   = 6
--local LOG_LEVEL_OFF     = 100

local log_input         = false
local log_buffer        = ""

logger = {}
function logger.init(max_line)
    local log_name  = sformat("%s-%d", quanta.service, quanta.index)
    local log_path = sformat("%s/%s/", environ.get("QUANTA_LOG_PATH"), quanta.service)
    local log_daemon = environ.status("QUANTA_DAEMON")
    llog.init(log_path, log_name, 0, max_line or 100000, log_daemon)
    logger.filter(environ.number("QUANTA_LOG_LVL"))
    if log_daemon then
        quanta.daemon(1, 1)
    end
end

logger.close = llog.close

function logger.filter(level)
    for lvl = LOG_LEVEL_DEBUG, LOG_LEVEL_FATAL do
        --filter(level, on/off)
        llog.filter(lvl, lvl >= level)
    end
end

local function logger_output(method, fmt, ...)
    local ok, fmt_log = pcall(sformat, fmt, ...)
    if not ok then
        local info = dgetinfo(2, "S")
        llog.warn(sformat("[logger][output] format failed: %s, source(%s:%s)", fmt_log, info.short_src, info.linedefined))
        return false
    end
    return method(fmt_log)
end

local function args_serialize(...)
    local args = tpack(...)
    for i, arg in ipairs(args) do
        if (type(arg) == "table") then
            args[i] = lserialize(arg)
        end
    end
    return args
end

function logger.debug(fmt, ...)
    if is_filter(LOG_LEVEL_DEBUG) then
        return
    end
    return logger_output(llog.debug, fmt, tunpack(args_serialize(...)))
end

function logger.info(fmt, ...)
    if is_filter(LOG_LEVEL_INFO) then
        return
    end
    return logger_output(llog.info, fmt, ...)
end

function logger.warn(fmt, ...)
    if is_filter(LOG_LEVEL_WARN) then
        return
    end
    return logger_output(llog.warn, fmt, tunpack(args_serialize(...)))
end

function logger.dump(fmt, ...)
    if is_filter(LOG_LEVEL_DUMP) then
        return
    end
    return logger_output(llog.dump, fmt, ...)
end

function logger.err(fmt, ...)
    if is_filter(LOG_LEVEL_ERROR) then
        return
    end
    return logger_output(llog.error, fmt, tunpack(args_serialize(...)))
end

function logger.fatal(fmt, ...)
    if is_filter(LOG_LEVEL_FATAL) then
        return
    end
    return logger_output(llog.fatal, fmt, tunpack(args_serialize(...)))
end

local function exec_command(cmd)
    stdout:write("\ncommand: " .. cmd .. "\n")
    local res = tpack(pcall(load(cmd)))
    if res[1] then
        stdout:write("result: " .. tconcat(res, ",", 2, #res))
    else
        stdout:write("error: " .. tconcat(res, ",", 2, #res))
    end
end

quanta.input = function(ch)
    if log_input then
        local sch = schar(ch)
        if ch ~= 13 and ch ~= 8 then
            stdout:write(sch)
            log_buffer = log_buffer .. sch
        end
        if ch == 8 then
            if #log_buffer > 0 then
                stdout:write(sch)
                stdout:write(schar(32))
                stdout:write(sch)
                log_buffer = ssub(log_buffer, 1, #log_buffer - 1)
            end
        end
        if ch == 13 or #log_buffer > 255 then
            llog.daemon(environ.status("QUANTA_DAEMON"))
            if #log_buffer > 0 then
                exec_command(log_buffer)
            end
            stdout:write("\n")
            log_input = false
            log_buffer = ""
        end
    else
        if ch == 13 then
            log_input = true
            llog.daemon(true)
            stdout:write("input> ")
        end
    end
end
