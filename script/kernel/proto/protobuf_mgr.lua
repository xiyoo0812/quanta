--protobuf_mgr.lua
local lfs       = require('lfs')
local protobuf  = require("driver.protobuf")

local pairs         = pairs
local pcall         = pcall
local open_file     = io.open
local ldir          = lfs.dir
local sfind         = string.find
local log_err       = logger.err
local setmetatable  = setmetatable
local pb_decode     = protobuf.decode
local pb_encode     = protobuf.encode
local pb_enum_id    = protobuf.enum_id

local ProtobufMgr = singleton()
function ProtobufMgr:__init()
    self.id_to_protos = {}
    self.proto_files = {}
    self.enum_defs   = {}
    self.open_reload_pb = false
end

--加载pb文件
function ProtobufMgr:setup(pb_files, enum_defs)
    self.proto_files = pb_files or {}
    for _, filename in ipairs(pb_files or {}) do
        protobuf.register_file("proto/" .. filename..".pb")
    end
    self:define_enum(enum_defs)
    self:define_command()
end

function ProtobufMgr:encode(cmd_id, data)
    local proto_name = self.id_to_protos[cmd_id]
    if not proto_name then
        log_err("[ProtobufMgr][encode] find proto name failed! cmd_id:%s", cmd_id)
        return nil
    end
    local ok, pb_str = pcall(pb_encode, proto_name, data or {})
    if ok then
        return pb_str
    end
end

function ProtobufMgr:decode(cmd_id, pb_str)
    local proto_name = self.id_to_protos[cmd_id]
    if not proto_name then
        log_err("[ProtobufMgr][decode] find proto name failed! cmd_id:%s", cmd_id)
        return nil
    end
    local ok, pb_data = pcall(pb_decode, proto_name, pb_str)
    if ok then
        return pb_data
    end
end

local function pbenum(package, enum_type)
    return function(_, enum_name)
        local enum_val = pb_enum_id(package .. "." .. enum_type, enum_name)
        if not enum_val then
            log_err("[ProtobufMgr][decode] no enum %s.%s.%s", package, enum_type, enum_name)
        end
        return enum_val
    end
end

function ProtobufMgr:define_enum(enum_defs)
    self.enum_defs = enum_defs or {}
    for package, enums in pairs(enum_defs or {}) do
        for _, enum_type in pairs(enums) do
            if not quanta_const[package] then
                quanta_const[package] = {}
            end
            quanta_const[package][enum_type] = setmetatable({}, {__index = pbenum(package, enum_type)})
        end
    end
end

function ProtobufMgr:define_command()
    for file_name in ldir("./proto/") do
        local pos = sfind(file_name, "%.lua")
        if pos then
            import("../proto/"..file_name..".lua")
            for id, proto_name in pairs(quanta[file_name]) do
                if self.id_to_protos[id] then
                    log_err("[ProtobufMgr][define_command] repeat id:%s, old:%s, new:%s", id, self.id_to_protos[id], proto_name)
                end
                self.id_to_protos[id] = proto_name
            end
        end
    end
    self.open_reload_pb = true
end

-- 重新加载
function ProtobufMgr:reload()
    if not self.open_reload_pb then
        return
    end
    -- gc env_
    protobuf.reset()

    -- register pb文件
    for _, filename in pairs(self.proto_files) do
        protobuf.register_file("proto/" .. filename..".pb")
    end

    -- 处理enum
    self:define_enum(self.enum_defs)

    -- 映射id与pb消息名
    self:define_command()
end

quanta.protobuf_mgr = ProtobufMgr()

return ProtobufMgr
