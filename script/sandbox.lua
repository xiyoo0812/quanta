--sandbox.lua
local llog      = require("lualog")
local lstdfs    = require("lstdfs")

local pairs     = pairs
local loadfile  = loadfile
local iopen     = io.open
local mabs      = math.abs
local log_info  = llog.info
local log_err   = llog.error
local tinsert   = table.insert
local sformat   = string.format
local dgetinfo  = debug.getinfo
local file_time = lstdfs.last_write_time

local load_files    = {}
local search_path   = {}

local function ssplit(str, token)
    local t = {}
    while #str > 0 do
        local pos = str:find(token)
        if pos then
            tinsert(t, str:sub(1, pos - 1))
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
        log_err(sformat("[sandbox][try_load] load file: %s ... [failed]\nerror : %s", node.filename, err))
        return
    end
    log_info(sformat("[sandbox][try_load] load file: %s ... [ok]", node.filename))
    return trunk_func()
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
    for path, node in pairs(load_files) do
        local filetime = file_time(node.fullpath)
        if mabs(node.time - filetime) > 1 then
            try_load(node)
        end
    end
end

function quanta.get(name)
    local global_obj = quanta[name]
    if not global_obj then
        local info = dgetinfo(2, "S")
        log_err(sformat("[quanta][get] %s not initial! source(%s:%s)", name, info.short_src, info.linedefined))
        return
    end
    return global_obj
end
