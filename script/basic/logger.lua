--logger.lua
--logger功能支持
local llog  = require("lualog")

local pcall         = pcall
local pairs         = pairs
local tostring      = tostring
local stdout        = io.stdout
local ssub          = string.sub
local schar         = string.char
local sformat       = string.format
local tinsert       = table.insert
local tpack         = table.pack
local tconcat       = table.concat
local tarray        = table_ext.is_array

logger = {}

local LOG_LEVEL_DEBUG   = 1     -- 用于调试消息的输出
local LOG_LEVEL_INFO    = 2     -- 用于跟踪程序运行进度
local LOG_LEVEL_WARN    = 3     -- 程序运行时发生异常
local LOG_LEVEL_DUMP    = 4     -- 数据异常dump
local LOG_LEVEL_ERROR   = 5     -- 程序运行时发生可预料的错误,此时通过错误处理,可以让程序恢复正常运行
local LOG_LEVEL_FATAL   = 6     -- 程序运行时发生致命的错误,需要人工干预

local log_input         = false
local log_buffer        = ""

function logger.init(max_line)
    local log_name  = sformat("%s-%d", quanta.service, quanta.index)
    local log_path = sformat("%s/%s/", environ.get("QUANTA_LOG_PATH"), quanta.service)
    local log_daemon = environ.status("QUANTA_DAEMON")
    llog.init(log_path, log_name, 0, max_line or 100000, log_daemon)
    --llog.filter(environ.number("QUANTA_LOG_LVL"))
    if log_daemon then
        quanta.daemon(1, 1)
    end
end

function logger.close()
    llog.close()
end

function logger.filter(level)
    llog.filter(level)
end

local function logger_output(method, level, fmt, ...)
    local filter = llog.is_filter(level)
    if filter == nil then
        return print(sformat(fmt, ...))
    end
    if not filter then
        method(sformat(fmt, ...))
    end
end

function logger.debug(fmt, ...)
    logger_output(llog.debug, LOG_LEVEL_DEBUG, fmt, ...)
end

function logger.info(fmt, ...)
    logger_output(llog.info, LOG_LEVEL_INFO, fmt, ...)
end

function logger.warn(fmt, ...)
    logger_output(llog.warn, LOG_LEVEL_WARN, fmt, ...)
end

function logger.dump(fmt, ...)
    logger_output(llog.dump, LOG_LEVEL_DUMP, fmt, ...)
end

function logger.err(fmt, ...)
    logger_output(llog.error, LOG_LEVEL_ERROR, fmt, ...)
end

function logger.fatal(fmt, ...)
    logger_output(llog.fatal, LOG_LEVEL_FATAL, fmt, ...)
end

function logger.serialize(tab)
    if llog.is_filter(LOG_LEVEL_DEBUG) then
        return tab
    end
    local mark = {}
    local assign = {}
    local function table2str(t, parent)
        local ret = {}
        mark[t] = parent
        local function array2str()
            for i, v in pairs(t) do
                local k = tostring(i)
                local dotkey = parent .. "[" .. k .. "]"
                local tpe = type(v)
                if tpe == "table" then
                    if mark[v] then
                        tinsert(assign, dotkey .. "=" .. mark[v])
                    else
                        tinsert(ret, table2str(v, dotkey))
                    end
                elseif tpe == "string" then
                    tinsert(ret, sformat("%q", v))
                elseif tpe == "number" then
                    if v == math.huge then
                        tinsert(ret, "math.huge")
                    elseif v == -math.huge then
                        tinsert(ret, "-math.huge")
                    else
                        tinsert(ret, tostring(v))
                    end
                else
                    tinsert(ret, tostring(v))
                end
            end
        end
        local function map2str()
            for f, v in pairs(t) do
                local k = type(f) == "number" and "[" .. f .. "]" or f
                local dotkey = parent .. (type(f) == "number" and k or "." .. k)
                local tpe = type(v)
                if tpe == "table" then
                    if mark[v] then
                        tinsert(assign, dotkey .. "=" .. mark[v])
                    else
                        tinsert(ret, sformat("%s=%s", k, table2str(v, dotkey)))
                    end
                elseif tpe == "string" then
                    tinsert(ret, sformat("%s=%q", k, v))
                elseif tpe == "number" then
                    if v == math.huge then
                        tinsert(ret, sformat("%s=%s", k, "math.huge"))
                    elseif v == -math.huge then
                        tinsert(ret, sformat("%s=%s", k, "-math.huge"))
                    else
                        tinsert(ret, sformat("%s=%s", k, tostring(v)))
                    end
                else
                    tinsert(ret, sformat("%s=%s", k, tostring(v)))
                end
            end
        end

        if tarray(t) then
            array2str()
        else
            map2str()
        end
        return "{" .. tconcat(ret,",") .. "}"
    end
    if type(tab) == "table" then
        return sformat("%s%s",  table2str(tab,"_"), tconcat(assign," "))
    else
        return tostring(tab)
    end
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
            if #log_buffer > 0 then
                exec_command(log_buffer)
            end
            stdout:write("\n")
            llog.daemon(environ.status("QUANTA_DAEMON"))
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
