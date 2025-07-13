--sandbox.lua
require("lualog")
require("lstdfs")
require("ltimer")

local pairs         = pairs
local loadfile      = loadfile
local mabs          = math.abs
local lprint        = log.print
local sgsub         = string.gsub
local ssplit        = string.split
local sformat       = string.format
local qgetenv       = quanta.getenv
local traceback     = debug.traceback
local file_time     = stdfs.last_write_time
local fexists       = stdfs.exists

local LOG_LEVEL     = log.LOG_LEVEL

local FEATURE       = "devops"
local THREAD_NAME   = quanta.thread

local load_status = "success"
local log_error = function(content)
    load_status = "failed"
    lprint(LOG_LEVEL.ERROR, 0, THREAD_NAME, nil, FEATURE, content)
end

local log_output = function(content)
    lprint(LOG_LEVEL.INFO, 0, THREAD_NAME, nil, FEATURE, content)
end

--加载部署日志
if qgetenv("QUANTA_LOG_PATH") then
    log.add_file_dest(FEATURE, "devops.log")
end

--加载lua文件搜索路径
local load_files    = {}
local load_codes    = {}
local search_path   = {}
for _, path in ipairs(ssplit(package.path, ";")) do
    local spath = path:sub(1, path:find("?") - 1)
    search_path[#search_path + 1] = sgsub(spath, "\\", "/")
end

local function search_load(node)
    local load_path = node.fullpath
    if load_path then
        node.time = file_time(load_path)
        return loadfile(load_path)
    end
    local filename = node.filename
    for _, path_root in pairs(search_path) do
        local fullpath = path_root .. filename
        if fexists(fullpath) then
            node.fullpath = fullpath
            node.time = file_time(fullpath)
            return loadfile(fullpath)
        end
    end
    return nil, "file not exist!"
end

local function try_load(node)
    local trunk_func, err = search_load(node)
    if not trunk_func then
        log_error(sformat("[sandbox][try_load] load file: %s ... [failed]\nerror : %s", node.filename, err))
        return
    end
    local ok, res = xpcall(trunk_func, traceback)
    if not ok then
        log_error(sformat("[sandbox][try_load] exec file: %s ... [failed]\nerror : %s", node.filename, res))
        return
    end
    if res then
        node.res = res
    end
    log_output(sformat("[sandbox][try_load] load file: %s ... [ok]", node.filename))
    return res
end

function import(filename)
    local node = load_codes[filename]
    if not node then
        node = { filename = filename }
        load_codes[filename] = node
        load_files[#load_files + 1] = node
    end
    if not node.time then
        try_load(node)
    end
    return node.res
end

function quanta.load_failed(content)
    log_error(content)
end

function quanta.load(name)
    return quanta[name]
end

function quanta.init(name, val)
    if not quanta[name] then
        quanta[name] = val or {}
    end
    return quanta[name]
end

function quanta.report(type)
    local divider = "----------------------------------------------------------------------------------------"
    local fmt = '{"type":"%s","pid":"%s","state":"%s","time":%s,"service":"%s"}'
    local str = sformat(fmt, type, quanta.pid, load_status, os.time(),  quanta.name)
    log_output(divider)
    log_output(str)
    log_output(divider)
end

function quanta.reload()
    load_status = "success"
    for _, node in ipairs(load_files) do
        if node.time then
            local filetime, err = file_time(node.fullpath)
            if filetime == 0 then
                log_error(sformat("[quanta][reload] %s get_time failed(%s)", node.fullpath, err))
                return
            end
            if mabs(node.time - filetime) > 1 then
                try_load(node)
            end
        end
    end
end
