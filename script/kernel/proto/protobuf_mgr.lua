--protobuf_mgr.lua
local lfs       = require('lfs')
local protobuf  = require("driver.protobuf")

local pairs         = pairs
local ipairs        = ipairs
local pcall         = pcall
local ldir          = lfs.dir
local sfind         = string.find
local sgsub         = string.gsub
local sformat       = string.format
local sends_with    = string_ext.ends_with
local ssplit        = string_ext.split
local tunpack       = table.unpack
local log_err       = logger.err
local env_get       = environ.get
local setmetatable  = setmetatable
local pb_decode     = protobuf.decode
local pb_encode     = protobuf.encode
local pb_enum_id    = protobuf.enum_id
local supper        = string.upper

local ProtobufMgr = singleton()
local prop = property(ProtobufMgr)
prop:accessor("pb_infos", {})
prop:accessor("pb_indexs", {})
prop:accessor("allow_reload", false)

function ProtobufMgr:__init()
    self:load_protos()
end

--加载pb文件
function ProtobufMgr:register_file(proto_dir, proto_file, pb_files)
    local full_name = sformat("%s%s", proto_dir, proto_file)
    if pb_files[full_name] then
        return
    end
    local pb_info = protobuf.parse_file(full_name)
    if pb_info then
        --注册依赖
        for _, dep_file in pairs(pb_info.dependency or {}) do
            self:register_file(proto_dir, sgsub(dep_file, ".proto", ".pb"), pb_files)
        end
        --注册pb文件
        protobuf.register_file(full_name)
        --注册emun
        for _, enum_type in pairs(pb_info.enum_type or {}) do
            self:define_enum(pb_info.package, enum_type.name)
        end
        pb_files[full_name] = pb_info
    end
end

--加载pb文件
function ProtobufMgr:load_protos()
    local proto_paths = ssplit(env_get("QUANTA_PROTO_PATH"), ";")
    for _, proto_path in pairs(proto_paths) do
        local pb_files = {}
        for file_name in ldir(proto_path) do
            local pos = sfind(file_name, ".pb")
            if pos then
                self:register_file(proto_path, file_name, pb_files)
            end
        end
        --注册事件索引
        for _, pb_info in pairs(pb_files) do
            self:define_command(pb_info)
        end
    end
end

function ProtobufMgr:encode(cmd_id, data)
    local proto_name = self.pb_indexs[cmd_id]
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
    local proto_name = self.pb_indexs[cmd_id]
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
            log_err("[pbenum] no enum %s.%s.%s", package, enum_type, enum_name)
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
    pb_enum[enum_type] = setmetatable({}, {__index = pbenum(package, enum_type)})
end

function ProtobufMgr:define_command(pb_info)
    local package_name = pb_info.package
    if sfind(pb_info.package, ".") then
        package_name = tunpack(ssplit(pb_info.package, "%."))
    end
    local enum_set = _G[package_name]
    if not enum_set then
        return
    end
    for _, data in ipairs(pb_info.message_type) do
        local proto_name = data.name
        local msg_name = "NID_" .. supper(proto_name)
        local full_name = pb_info.package .. "." .. proto_name
        if sends_with(proto_name, "_req") or sends_with(proto_name, "_res") or sends_with(proto_name, "_ntf") then
            local msg_id = nil
            for enum_type, enum in pairs(enum_set) do
                local var = pb_enum_id(package_name .. "." .. enum_type, msg_name)
                if var then
                    msg_id = var
                    break
                end
            end
            if msg_id then
                local old_full_name = self.pb_indexs[msg_id]
                if old_full_name then
                    local pos = old_full_name:find("%.")
                    local old_package = old_full_name:sub(1, pos - 1)
                    if old_package == pb_info.package then
                        log_err("[ProtobufMgr][define_command] repeat id:%s, old:%s, new:%s", msg_id, old_full_name, proto_name)
                    end
                end
                self.pb_indexs[msg_id] = full_name
                self.pb_infos[full_name] = { id = msg_id, field = data.field }
            else
                log_err("[ProtobufMgr][define_command] proto_name: [%s] can't find msg enum:[%s] !", proto_name, msg_name)
            end
        else
            self.pb_infos[full_name] = { id = 0, field = data.field }
        end
    end
    self.allow_reload = true
end

-- 重新加载
function ProtobufMgr:reload()
    if not self.allow_reload then
        return
    end
    -- gc env_
    protobuf.reset()
    -- register pb文件
    self:load_protos()
end

quanta.protobuf_mgr = ProtobufMgr()

return ProtobufMgr
