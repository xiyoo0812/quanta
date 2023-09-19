--accord.lua

local ldir          = stdfs.dir
local lstem         = stdfs.stem
local lmkdir        = stdfs.mkdir
local lappend       = stdfs.append
local lfilename     = stdfs.filename
local lextension    = stdfs.extension
local lcurdir       = stdfs.current_path
local serialize     = luakit.serialize
local pb_enum_id    = protobuf.enum
local json_encode   = json.encode
local tunpack       = table.unpack
local sformat       = string.format
local supper        = string.upper
local ogetenv       = os.getenv

local pb_indexs = {}

local function ssplit(str, token)
    local t = {}
    while #str > 0 do
        local pos = str:find(token)
        if not pos then
            t[#t + 1] = str
            break
        end
        if pos > 1 then
            t[#t + 1] = str:sub(1, pos - 1)
        end
        str = str:sub(pos + 1, #str)
    end
    return t
end

local function sends_with(str, ending)
    return str:sub(-#ending) == ending
end

local function parse_message(full_name, proto_name)
    local proto_isreq = sends_with(proto_name, "_req")
    if proto_isreq then
        local package_name = tunpack(ssplit(full_name, "."))
        local enum_type = package_name .. ".NCmdId"
        local msg_name = "NID_" .. supper(proto_name)
        local msg_id = pb_enum_id(enum_type, msg_name)
        if msg_id then
            local fields = {}
            for name, _, typ in protobuf.fields(full_name) do
                fields[name] = (typ == "string") and "xxx" or 0
            end
            pb_indexs[msg_name] = { 
                msg_id = msg_id,
                name = msg_name,
                fields = fields,
            }
        end
    end
    return pb_indexs
end

--加载pb文件
local function load_pbfiles(proto_dir, proto_file)
    local full_name = lappend(proto_dir, proto_file)
    --加载PB文件
    protobuf.loadfile(full_name)
    --注册CMDID和PB的映射
    for name, basename, typ in protobuf.types() do
        if typ == "message" then
            parse_message(name, basename)
        end
    end
end

--加载pb文件
local function load_protocol(proto_path)
    local dir_files = ldir(proto_path)
    for _, file in pairs(dir_files) do
        if lextension(file.name) == ".pb" then
            load_pbfiles(proto_path, lfilename(file.name))
        end
    end
end

--加载case文件
local function load_cases(tool_dir, case_dir)
    local tcases = {}
    local case_path = lappend(tool_dir, case_dir)
    local dir_files = ldir(case_path)
    for _, file in pairs(dir_files or {}) do
        if lextension(file.name) == ".lua" then
            local name = lstem(file.name)
            tcases[name] = require(sformat("%s.%s", case_dir, name))
        end
    end
    return tcases
end

local function export_json(input, output)
    local configs = {}
    configs.accord = pb_indexs
    configs.servers = require("server")
    configs.cases = load_cases(input, "cases")
    --export
    local jdata = json_encode(configs)
    local ldata = serialize(configs)
    local jsonname = lappend(input, "accord_conf.json")
    local json_file = io.open(jsonname, "w")
    json_file:write(jdata)
    json_file:close()
    local confname = lappend(output, "accord_conf.lua")
    local conf_file = io.open(confname, "w")
    conf_file:write("--luacheck: ignore 631\n")
    conf_file:write(sformat("return {\n    lua = %s,\n    json = [[%s]]\n}\n", ldata, jdata))
    conf_file:close()
    print("export accord config success!")
end

local proto = lcurdir()
local input = lcurdir()
local output = lcurdir()
local env_proto = ogetenv("QUANTA_PROTO")
if not env_proto or #env_proto == 0 then
    print("proto dir not config!")
else
    proto = lappend(proto, env_proto)
end
local env_input = ogetenv("QUANTA_INPUT")
if not env_input or #env_input == 0 then
    print("input dir not config!")
else
    input = lappend(input, env_input)
end
local env_output = ogetenv("QUANTA_OUTPUT")
if not env_output or #env_output == 0 then
    print("output dir not config!")
else
    output = lappend(output, env_output)
    lmkdir(output)
end

load_protocol(proto)
export_json(input, output)

os.exit()
