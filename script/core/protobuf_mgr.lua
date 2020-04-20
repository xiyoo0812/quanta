--protobuf_mgr.lua
local protobuf = require("lua.common.protobuf")

local _G            = _G
local pairs         = pairs
local pcall         = pcall
local open_file     = io.open
local log_err       = logger.err
local setmetatable  = setmetatable
local pb_decode     = protobuf.decode
local pb_encode     = protobuf.encode
local pb_enum_id    = protobuf.enum_id

local ProtobufMgr = singleton()
function ProtobufMgr:__init()
    self.id_to_names = {}
    self.proto_names = {}
    self.enum_defs   = {}
    self.open_reload_pb = false
end

--加载pb文件
function ProtobufMgr:setup(pb_files)
    self.proto_names = pb_files
    for _, filename in ipairs(pb_files) do
        protobuf.register_file("proto/" .. filename..".pb")
    end
end

function ProtobufMgr:encode(protocol, data)
    local msg_name = self.id_to_names[protocol]
    if not msg_name then
        log_err("[ProtobufMgr][encode] find msg name failed! cmd_id:%s", protocol)
        return nil
    end
    local ok, pb_str = pcall(pb_encode, msg_name, data or {})
    if ok then
        return pb_str
    end
end

function ProtobufMgr:decode(protocol, pb_str)
    local msg_name = self.id_to_names[protocol]
    if not msg_name then
        log_err("[ProtobufMgr][decode] find msg name failed! cmd_id:%s", protocol)
        return nil
    end
    local ok, pb_data = pcall(pb_decode, msg_name, pb_str)
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
    self.enum_defs = enum_defs
    for package, enums in pairs(enum_defs) do
        for _, enum_type in pairs(enums) do
            if not _G[package] then
                _G[package] = {}
            end
            _G[package][enum_type] = setmetatable({}, {__index = pbenum(package, enum_type)})
        end
    end
end

function ProtobufMgr:define_proto(protos_)
    for _, file_name in pairs(protos_) do
        local file = open_file("proto/"..file_name..".lua", "rb")
        if file then
            file:close()
            import("../proto/"..file_name..".lua")
            for id, name in pairs(quanta[file_name]) do
                if self.id_to_names[id] then
                    log_err("[ProtobufMgr][define_proto] repeat id:%s, old:%s, new:%s", id, self.id_to_names[id], name)
                end
                self.id_to_names[id] = name
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
    for _, filename in pairs(self.proto_names) do
        protobuf.register_file("proto/" .. filename..".pb")
    end

    -- 处理enum
    self:define_enum(self.enum_defs)

    -- 映射id与pb消息名
    for _, file_name in pairs(self.proto_names) do
        if quanta[file_name] then
            for id, name in pairs(quanta[file_name]) do
                self.id_to_names[id] = name
            end
        end
    end
end

quanta.protobuf_mgr = ProtobufMgr()

return ProtobufMgr
