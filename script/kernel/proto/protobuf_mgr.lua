--protobuf_mgr.lua
local lfs       = require('lfs')
local protobuf  = require("driver.protobuf")

local pairs         = pairs
local ipairs        = ipairs
local pcall         = pcall
local open_file     = io.open
local ldir          = lfs.dir
local sfind         = string.find
local sgsub         = string.gsub
local sformat       = string.format
local ssplit        = string_ext.split
local log_err       = logger.err
local env_get       = environ.get
local setmetatable  = setmetatable
local pb_decode     = protobuf.decode
local pb_encode     = protobuf.encode
local pb_enum_id    = protobuf.enum_id

local ProtobufMgr = singleton()
function ProtobufMgr:__init()
    self.id_to_protos = {}
    self.open_reload_pb = false
    --初始化
    self:load_protos()
end

--加载pb文件
function ProtobufMgr:register_file(proto_dir, proto_file)
    local full_name = sformat("%s%s", proto_dir, proto_file)
    local pb_info = protobuf.parse_file(full_name)
    if pb_info then
        --注册依赖
        for _, dep_file in pairs(pb_info.dependency or {}) do
            self:register_file(proto_dir, sgsub(dep_file, ".proto", ".pb"))
        end
        --注册pb文件
        protobuf.register_file(full_name)
        --注册emun
        for _, enum_type in pairs(pb_info.enum_type or {}) do
            self:define_enum(pb_info.package, enum_type.name)
        end
    end
end

--加载pb文件
function ProtobufMgr:load_protos()
    local proto_dir = env_get("QUANTA_PROTO")
    if proto_dir then
        for file_name in ldir(proto_dir) do
            local pos = sfind(file_name, ".pb")
            if pos then
                self:register_file(proto_dir, file_name)
            end
        end
        self:define_command(proto_dir)
    end
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

local function build_enum(package)
    local pb_enum = _G
    local nodes = ssplit(package, "%.")
    for _, name in ipairs(nodes) do
        if not pb_enum[name] then
            pb_enum[name] = {}
        end
        pb_enum = pb_enum[name]
    end
    return pb_enum
end

function ProtobufMgr:define_enum(package, enum_type)
    local pb_enum = build_enum(package)
    print(pb_enum, _G)
    pb_enum[enum_type] = setmetatable({}, {__index = pbenum(package, enum_type)})
end

function ProtobufMgr:define_command(proto_dir)
    for file_name in ldir(proto_dir) do
        local pos = sfind(file_name, "%.lua")
        if pos then
            local res = import(sformat("%s%s", proto_dir, file_name))
            for id, proto_name in pairs(res or {}) do
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
    self:load_protos()
    -- 映射id与pb消息名
    self:define_command()
end

quanta.protobuf_mgr = ProtobufMgr()

return ProtobufMgr