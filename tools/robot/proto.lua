--index.lua
local ljson         = require("ljson")
local lstdfs        = require("lstdfs")
local protobuf      = require("luapb")

local io_open       = io.open
local qgetenv       = quanta.getenv
local tunpack       = table.unpack
local ssub          = string.sub
local ssplit        = string.split
local supper        = string.upper
local lmkdir        = lstdfs.mkdir
local lappend       = lstdfs.append
local lcurdir       = lstdfs.current_path

local field_type = {
    [1] =  "double",
    [2] =  "float",
    [3] =  "int64/sint64",
    [4] =  "uint64",
    [5] =  "int32/sint32",
    [6] =  "fixed64",
    [7] =  "fixed32",
    [8] =  "bool",
    [9] =  "string",
    [10] =  "group",
    [11] =  "message",
    [12] =  "bytes",
    [13] =  "uint32",
    [14] =  "enum",
    [15] =  "sfixed32",
    [16] =  "sfixed64",
    [17] =  "sint32",
    [18] =  "sint64"
}

-- 初始化协议数据
local function export_proto(input, output)
    local protobufs = {}
    protobuf.loadfile(input)
    local messages = protobuf.messages()
    for full_name, proto_name in pairs(messages) do
        local package_name = tunpack(ssplit(full_name, "."))
        local enum_type = package_name .. ".NCmdId"
        local msg_name = "NID_" .. supper(proto_name)
        local msg_id = protobuf.enum(enum_type, msg_name)
        if msg_id then
            local values = {}
            local fields = protobuf.fields(full_name)
            for name, type in pairs(fields) do
                values[name] = field_type[type]
            end
            protobufs[msg_name] = {
                msg_id = msg_id,
                name = msg_name,
                fields = values,
                type = ssub(proto_name, -3)
            }
        end
    end
    local json = ljson.pretty(protobufs)
    local fname = lappend(output, "proto.json")
    local ofile = io_open(fname, "w")
    ofile:write(json)
    ofile:close()
end

local function export_config()
    local input = nil
    local output = lcurdir()
    local env_input = qgetenv("QUANTA_INPUT")
    if not env_input or #env_input == 0 then
        print("input dir not config!")
        return
    end
    input = lappend(input, env_input)
    local env_output = qgetenv("QUANTA_OUTPUT")
    if not env_output or #env_output == 0 then
        print("output dir not config!")
    end
    output = lappend(output, env_output)
    lmkdir(output)
    return input, output
end

print("start export proto data!")
local input, output = export_config()
local ok, err = pcall(export_proto, input, output)
if not ok then
    print("export proto data failed:", err)
    return
end
print("export proto data success!")
