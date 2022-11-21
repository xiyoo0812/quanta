--sandbox.lua
local logger    = require("lualog")
local lstdfs    = require("lstdfs")

local pairs     = pairs
local loadfile  = loadfile
local iopen     = io.open
local mabs      = math.abs
local sformat   = string.format
local dtraceback= debug.traceback
local file_time = lstdfs.last_write_time

local logtag    = quanta.logtag
local log_output= function(lvl, ctx)
    logger[lvl](logtag .. ctx)
end

local load_files    = {}
local search_path   = {}

local function ssplit(str, token)
    local t = {}
    while #str > 0 do
        local pos = str:find(token)
        if pos then
            t[#t + 1] = str:sub(1, pos - 1)
            str = str:sub(pos + 1, #str)
        else
            t[#t + 1] = str
            break
        end
    end
    return t
end

--加载lua文件搜索路径
for _, path in ipairs(ssplit(package.path, ";")) do
    search_path[#search_path + 1] = path:sub(1, path:find("?") - 1)
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
        local file = iopen(fullpath)
        if file then
            file:close()
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
        log_output("error", sformat("[sandbox][try_load] load file: %s ... [failed]\nerror : %s", node.filename, err))
        return
    end
    local ok, res = xpcall(trunk_func, dtraceback)
    if not ok then
        log_output("error", sformat("[sandbox][try_load] exec file: %s ... [failed]\nerror : %s", node.filename, res))
        return
    end
    log_output("info", sformat("[sandbox][try_load] load file: %s ... [ok]", node.filename))
    return res
end

function import(filename)
    local node = load_files[filename]
    if not node then
        node = { filename = filename }
        load_files[filename] = node
    end
    if not node.time then
        local res = try_load(node)
        if res then
            node.res = res
        end
    end
    return node.res
end

function quanta.reload()
    for _, node in pairs(load_files) do
        if node.time then
            local filetime, err = file_time(node.fullpath)
            if filetime == 0 then
                log_output("error", sformat("[quanta][reload] %s get_time failed(%s)", node.fullpath, err))
                return
            end
            if mabs(node.time - filetime) > 1 then
                try_load(node)
            end
        end
    end
end

