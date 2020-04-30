--logger.lua
--logger功能支持
local lfs = require('lfs')

local pcall         = pcall
local pairs         = pairs
local tostring      = tostring
local iopen         = io.open
local stdout        = io.stdout
local otime         = os.time
local odate         = os.date
local lmkdir        = lfs.mkdir
local ssub          = string.sub
local schar         = string.char
local sformat       = string.format
local tinsert       = table.insert
local tpack         = table.pack
local tconcat       = table.concat
local dtraceback    = debug.traceback
local tarray        = table_ext.is_array

logger = {}

local LOG_LEVEL_DEBUG   = 1     -- 用于调试消息的输出
local LOG_LEVEL_INFO    = 2     -- 用于跟踪程序运行进度
local LOG_LEVEL_WARN    = 3     -- 程序运行时发生异常
local LOG_LEVEL_ERROR   = 4     -- 程序运行时发生可预料的错误,此时通过错误处理,可以让程序恢复正常运行
local LOG_LEVEL_OFF     = 100   -- 关闭所有消息输出

local log_file          = nil
local log_filename      = nil
local log_daemon        = false
local log_input         = false
local log_listener      = nil
local log_buffer        = ""
local log_line_count    = 0
local log_max_line      = 100000
local log_lvl           = LOG_LEVEL_INFO

function logger.init(max_line)
    log_max_line = max_line or log_max_line
    log_lvl = environ.number("QUANTA_LOG_LVL")
    log_daemon = environ.status("QUANTA_DAEMON")
    --构建日志目录
    local log_path = environ.get("QUANTA_LOG_PATH")
    lmkdir(log_path)
    log_file_path = sformat("%s/%s", log_path, quanta.service)
    lmkdir(log_file_path)
    if log_daemon then
        quanta.daemon(1, 1)
    end
    log_listener = quanta.listener
    log_filename = sformat("%s/%s-%d", log_file_path, quanta.service, quanta.index)
end

function logger.level(level)
    log_lvl = level
end

function logger.off(level)
    log_lvl = LOG_LEVEL_OFF
end

function logger.close()
    if log_file then
        log_file:close()
        log_file = nil
    end
end

local function log_write(cate, color, fmt, ...)
    local time = odate("%Y%m%d-%H:%M:%S", otime())
    fmt = sformat("%s/%s\t%s\n", time, cate, tostring(fmt))
    local ok, line = pcall(sformat, fmt, ...)
    if not ok then
        line = sformat("%slogger error: %s\n%s", fmt, line, dtraceback())
    end
    if not log_daemon then
        if quanta.platform == "windows" then
            stdout:write(color .. line)
        else
            stdout:write(line)
        end
    end
    if log_file == nil or log_line_count >= log_max_line then
        if log_file then
            log_file:close()
        end
        local file_time = odate("%Y%m%d-%H%M%S", otime())
        local filename = sformat("%s-%s.log", log_filename, file_time)
        log_file = iopen(filename, "w")
        if log_file == nil then
            return
        end
        log_file:setvbuf("no")
        log_line_count = 0
    end
    if not log_file:write(line) then
        log_file:close()
        log_file = nil
        log_line_count = 0
        return
    end
    log_line_count = log_line_count + 1
    log_listener:notify_trigger("on_log_output", line)
end

-- 字体颜色
-- 30:黑 31:红 32:绿 33:黄 34:蓝 35:紫 36:深绿 37:白色

function logger.debug(fmt, ...)
    if log_lvl <= LOG_LEVEL_DEBUG then
        log_write("DEBUG", "\x1B[37m", fmt, ...)
    end
end

function logger.info(fmt, ...)
    if log_lvl <= LOG_LEVEL_INFO then
        log_write("INFO", "\x1B[32m", fmt, ...)
    end
end

function logger.warn(fmt, ...)
    if log_lvl <= LOG_LEVEL_WARN then
        log_write("WARN", "\x1B[33m", fmt, ...)
    end
end

function logger.err(fmt, ...)
    if log_lvl <= LOG_LEVEL_ERROR then
        log_write("ERROR", "\x1B[31m", fmt, ...)
    end
end

function logger.serialize(tab)
    if log_lvl > LOG_LEVEL_DEBUG then
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
            log_daemon = environ.status("QUANTA_DAEMON")
            log_input = false
            log_buffer = ""
        end
    else
        if ch == 13 then
            log_input = true
            log_daemon = true
            stdout:write("input> ")
        end
    end
end
