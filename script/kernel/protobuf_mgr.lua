--protobuf_mgr.lua
local protobuf      = require('pb')
local lstdfs        = require('lstdfs')

local pairs         = pairs
local ipairs        = ipairs
local pcall         = pcall
local supper        = string.upper
local tunpack       = table.unpack
local dgetinfo      = debug.getinfo
local setmetatable  = setmetatable
local log_err       = logger.err
local env_get       = environ.get
local ldir          = lstdfs.dir
local lappend       = lstdfs.append
local lfilename     = lstdfs.filename
local lextension    = lstdfs.extension
local pb_enum_id    = protobuf.enum
local pb_decode     = protobuf.decode
local pb_encode     = protobuf.encode
local ssplit        = string_ext.split
local sends_with    = string_ext.ends_with

local ProtobufMgr = singleton()
local prop = property(ProtobufMgr)
prop:reader("pb_naems", {})
prop:reader("pb_indexs", {})
prop:reader("pb_callbacks", {})
prop:reader("allow_reload", false)

function ProtobufMgr:__init()
    self:load_protos()
end

--返回回调id
function ProtobufMgr:callback_id(req_id)
    return self.pb_callbacks[req_id]
end

--返回协议名称
function ProtobufMgr:msg_name(cmd_id)
    return self.pb_naems[cmd_id]
end

function ProtobufMgr:enum(ename, ekey)
    local emun = ncmd_cs[ename]
    if not emun then
        local info = dgetinfo(2, "S")
        log_err("[ProtobufMgr][enum] %s not initial! source(%s:%s)", ename, info.short_src, info.linedefined)
        return
    end
    local value = emun[ekey]
    if not value then
        local info = dgetinfo(2, "S")
        log_err("[ProtobufMgr][enum] %s.%s not defined! source(%s:%s)", ename, ekey, info.short_src, info.linedefined)
        return
    end
    return value
end

function ProtobufMgr:error_code(err_key)
    return self:enum("ErrorCode", err_key)
end

function ProtobufMgr:msg_id(msg_name)
    return self:enum("NCmdId", msg_name)
end

--加载pb文件
function ProtobufMgr:load_pbfiles(proto_dir, proto_file)
    local full_name = lappend(proto_dir, proto_file)
    --加载PB文件
    protobuf.loadfile(full_name)
    --设置枚举解析成number
    protobuf.option("enum_as_value")
    --注册枚举
    for name, basename, typ in protobuf.types() do
        if typ == "enum" then
            self:define_enum(name)
        end
    end
    --注册CMDID和PB的映射
    for name, basename, typ in protobuf.types() do
        if typ == "message" then
            self:define_command(name, basename)
        end
    end
end

--加载pb文件
function ProtobufMgr:load_protos()
    local proto_paths = ssplit(env_get("QUANTA_PROTO_PATH", ""), ";")
    for _, proto_path in pairs(proto_paths) do
        local dir_files = ldir(proto_path)
        for _, file in pairs(dir_files) do
            if lextension(file.name) == ".pb" then
                local filename = lfilename(file.name)
                self:load_pbfiles(proto_path, filename)
            end
        end
    end
    self.allow_reload = true
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
        return pb_data, proto_name
    end
end

local function pbenum(full_name)
    return function(_, enum_name)
        local enum_val = pb_enum_id(full_name, enum_name)
        if not enum_val then
            log_err("[pbenum] no enum %s.%s", full_name, enum_name)
        end
        return enum_val
    end
end

function ProtobufMgr:define_enum(full_name)
    local pb_enum = _G
    local nodes = ssplit(full_name, "%.")
    for _, name in ipairs(nodes) do
        if not pb_enum[name] then
            pb_enum[name] = {}
        end
        pb_enum = pb_enum[name]
    end
    setmetatable(pb_enum, {__index = pbenum(full_name)})
end

function ProtobufMgr:define_command(full_name, proto_name)
    local package_name = tunpack(ssplit(full_name, "%."))
    local enum_set = _G[package_name]
    if not enum_set then
        return
    end
    local msg_name = "NID_" .. supper(proto_name)
    local proto_isreq = sends_with(proto_name, "_req")
    if proto_isreq or sends_with(proto_name, "_res") or sends_with(proto_name, "_ntf") then
        for enum_type, enum in pairs(enum_set) do
            local msg_id = pb_enum_id(package_name .. "." .. enum_type, msg_name)
            if msg_id then
                self.pb_naems[msg_id] = msg_name
                self.pb_indexs[msg_id] = full_name
                if proto_isreq then
                    local msg_res_name = msg_name:sub(0, -2) .. "S"
                    local msg_res_id = pb_enum_id(package_name .. "." .. enum_type, msg_res_name)
                    if msg_res_id then
                        self.pb_callbacks[msg_id] = msg_res_id
                    end
                end
                return
            end
        end
        log_err("[ProtobufMgr][define_command] proto_name: [%s] can't find msg enum:[%s] !", proto_name, msg_name)
    end
end

-- 重新加载
function ProtobufMgr:reload()
    if not self.allow_reload then
        return
    end
    -- gc env_
    protobuf.clear()
    -- register pb文件
    self:load_protos()
end

quanta.protobuf_mgr = ProtobufMgr()

return ProtobufMgr
