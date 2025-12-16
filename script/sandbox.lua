--sandbox.lua
require("lualog")
require("lstdfs")

local pairs         = pairs
local loadfile      = loadfile
local sgsub         = string.gsub
local ssplit        = string.split
local qgenv         = quanta.getenv
local traceback     = debug.traceback
local file_time     = stdfs.last_write_time
local fexists       = stdfs.exists
local lprint        = log.print

local THREAD_NAME   = quanta.thread
local LOG_LEVEL     = log.LOG_LEVEL

local function log_info(fmt, ...)
    lprint(LOG_LEVEL.DEBUG, 0, THREAD_NAME, nil, "", fmt, ...)
end

local function log_err(fmt, ...)
    lprint(LOG_LEVEL.ERROR, 0, THREAD_NAME, nil, "", fmt, ...)
end

--设置日志路径和服务
log.option(qgenv("QUANTA_LOG_PATH"), qgenv("QUANTA_SERVICE"), qgenv("QUANTA_INDEX"))
--附加日志代理
log.display()

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
        log_err("[sandbox][try_load] load file: {} ... [failed]\nerror : {}", node.filename, err)
        return
    end
    local ok, res = xpcall(trunk_func, traceback)
    if not ok then
        log_err("[sandbox][try_load] exec file: {} ... [failed]\nerror : {}", node.filename, res)
        return
    end
    if res then
        node.res = res
    end
    log_info("[sandbox][try_load] load file: {} ... [ok]", node.filename)
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

function quanta.load(name)
    return quanta[name]
end

function quanta.init(name, val)
    if not quanta[name] then
        quanta[name] = val or {}
    end
    return quanta[name]
end

function quanta.reload()
    for _, node in ipairs(load_files) do
        if node.time then
            local filetime, err = file_time(node.fullpath)
            if filetime == 0 then
                log_err("[quanta][reload] {} get_time failed({})", node.fullpath, err)
                return
            end
            if node.time ~= filetime then
                try_load(node)
            end
        end
    end
end
