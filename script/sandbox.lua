--sandbox.lua

local pcall     = pcall
local pairs     = pairs
local loadfile  = loadfile
local otime     = os.time
local mabs      = math.abs
local tinsert   = table.insert
local sformat   = string.format
local file_time = quanta.get_file_time

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
    local trunk
    local filename = node.filename
    for _, path_root in pairs(search_path) do
        local fullpath = path_root .. filename
        trunk = loadfile(fullpath)
        if trunk then
            node.fullpath = fullpath
            node.time = file_time(fullpath)
            return trunk
        end
    end
end

local function try_load(node)
    local trunk = search_load(node)
    if not trunk then
        print(sformat("load file: %s ... [failed]", node.filename))
        return
    end
    local ok, res = pcall(trunk)
    if not ok then
        print(sformat("exec file: %s ... [failed]\nerror : %s", node.filename, res))
        return
    end
    print(sformat("load file: %s ... [ok]", node.filename))
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

quanta.reload = function()
    local now = otime()
    for path, node in pairs(load_files) do
        local filetime = file_time(node.fullpath)
        if filetime ~= node.time and filetime ~= 0 and mabs(now - filetime) > 1 then
            try_load(node)
        end
    end
end
