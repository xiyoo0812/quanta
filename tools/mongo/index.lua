--index.lua
local lstdfs        = require('lstdfs')

local io_open       = io.open
local ogetenv       = os.getenv
local tinsert       = table.insert
local sformat       = string.format
local lmkdir        = lstdfs.mkdir
local lappend       = lstdfs.append
local lcurdir       = lstdfs.current_path

local load_table = function(str)
    local func = load("return " .. str)
    if func then
        return func()
    end
end

local function generate_js(input_path, ouput_path)
    local ifile = lappend(input_path, "cache_cfg.lua")
    local fs = io_open(ifile, "r")
    if not fs then
        error(sformat("read %s error", ifile))
        return
    end

    local configs = {}
    local content = fs:read("*all")
    for chunk in content:gmatch("%((%b{})%)[%s]*") do
        local tab = load_table(chunk)
        if type(tab) ~= "table" then
            error("parse %d error", chunk)
            return
        end
        tinsert(configs, tab)
    end

    local ofile = lappend(ouput_path, "mongo.js")
    local idx_file = io_open(ofile, "w")
    idx_file:write(sformat("//generate time: %s\n\n", os.date()))
    idx_file:write("db = db.getSiblingDB('quanta')\n\n")
    for _, conf in ipairs(configs) do
        -- 删除以前集合
        local sheet, key, key2 = conf.sheet, conf.key, conf.key2
        print(sformat("generate [%s] script", sheet))
        idx_file:write("//------------------------------------------------------------------------\n")
        idx_file:write(sformat("//generate %s\n", sheet))
        idx_file:write(sformat("db.getCollection(\"%s\").drop();\n", sheet))
        -- 创建新集合
        idx_file:write(sformat("db.createCollection(\"%s\");\n", sheet))
        --创建索引，默认升序
        idx_file:write(sformat("db.getCollection(\"%s\").createIndex({%s: 1}, {name: \"%s\",unique: true});\n", sheet, key, key))
        if key2 then
            idx_file:write(sformat("db.getCollection(\"%s\").createIndex({%s: 1}, {name: \"%s\",unique: true});\n", sheet, key2, key2)) 
        end
        idx_file:write("//------------------------------------------------------------------------\n\n")
    end
    idx_file:close()
end

local function export_config()
    local input = lcurdir()
    local output = lcurdir()
    local env_input = ogetenv("QUANTA_INPUT")
    if not env_input or #env_input == 0 then
        print("input dir not config!")
        return
    end
    input = lappend(input, env_input)
    local env_output = ogetenv("QUANTA_OUTPUT")
    if not env_output or #env_output == 0 then
        print("output dir not config!")
    end
    output = lappend(output, env_output)
    lmkdir(output)
    return input, output
end

print("start generate mongo index script!")
local input, output = export_config()
local ok, err = pcall(generate_js, input, output)
if not ok then
    print("generate mongo index failed:", err)
    return
end
print("generate mongo index script success!")
