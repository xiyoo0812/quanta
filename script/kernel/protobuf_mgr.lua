--protobuf_mgr.lua
local protobuf      = require('pb')
local lstdfs        = require('lstdfs')

local pairs         = pairs
local ipairs        = ipairs
local pcall         = pcall
local log_err       = logger.err
local log_warn      = logger.warn
local env_get       = environ.get
local ldir          = lstdfs.dir
local lappend       = lstdfs.append
local lfilename     = lstdfs.filename
local lextension    = lstdfs.extension
local pb_enum_id    = protobuf.enum
local pb_decode     = protobuf.decode
local pb_encode     = protobuf.encode
local tunpack       = table.unpack
local supper        = string.upper
local ssplit        = qstring.split
local sends_with    = qstring.ends_with
local dgetinfo      = debug.getinfo
local setmetatable  = setmetatable

local event_mgr     = quanta.get("event_mgr")

local ProtobufMgr = singleton()
local prop = property(ProtobufMgr)
prop:reader("pb_names", {})
prop:reader("pb_indexs", {})
prop:reader("pb_callbacks", {})
prop:reader("allow_reload", false)

function ProtobufMgr:__init()
    self:load_protos()
    --监听热更新
    event_mgr:add_trigger(self, "on_service_hotfix")
end

--返回回调id
function ProtobufMgr:callback_id(cmd_id)
    local pb_cbid = self.pb_callbacks[cmd_id]
    if not pb_cbid then
        log_warn("[ProtobufMgr][callback_id] cmdid %s find callback_id is nil", cmd_id)
    end
    return pb_cbid
end

--返回协议名称
function ProtobufMgr:msg_name(pb_cmd)
    return self.pb_indexs[pb_cmd].name
end

function ProtobufMgr:msg_id(pb_cmd)
    return self.pb_indexs[pb_cmd].id
end

function ProtobufMgr:error_code(err_key)
    return self:enum("ErrorCode", err_key)
end

function ProtobufMgr:enum(ename, ekey)
    local emun = ncmd_cs[ename]
    if not emun then
        local info = dgetinfo(2, "S")
        log_warn("[ProtobufMgr][enum] %s not initial! source(%s:%s)", ename, info.short_src, info.linedefined)
        return
    end
    local value = emun[ekey]
    if not value then
        local info = dgetinfo(2, "S")
        log_warn("[ProtobufMgr][enum] %s.%s not defined! source(%s:%s)", ename, ekey, info.short_src, info.linedefined)
        return
    end
    return value
end

--加载pb文件
function ProtobufMgr:load_pbfiles(proto_dir, proto_file)
    local full_name = lappend(proto_dir, proto_file)
    --加载PB文件
    protobuf.loadfile(full_name)
    --设置枚举解析成number
    protobuf.option("enum_as_value")
    --注册枚举
    for name, _, typ in protobuf.types() do
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

function ProtobufMgr:encode_byname(pb_name, data)
    local ok, pb_str = pcall(pb_encode, pb_name, data or {})
    if ok then
        return pb_str
    end
end

function ProtobufMgr:encode(pb_cmd, data)
    local proto = self.pb_indexs[pb_cmd]
    if not proto then
        log_err("[ProtobufMgr][encode] find proto failed! cmd:%s", pb_cmd)
        return
    end
    local ok, pb_str = pcall(pb_encode, proto.name, data or {})
    if ok then
        return pb_str, proto.id
    end
end

function ProtobufMgr:decode_byname(pb_name, pb_str)
    local ok, pb_data = pcall(pb_decode, pb_name, pb_str)
    if ok then
        return pb_data
    end
end

function ProtobufMgr:decode(pb_cmd, pb_str)
    local proto = self.pb_indexs[pb_cmd]
    if not proto then
        log_err("[ProtobufMgr][decode] find proto failed! cmd:%s", pb_cmd)
        return
    end
    local ok, pb_data = pcall(pb_decode, proto.name, pb_str)
    if ok then
        return pb_data, proto.name
    end
end

local function pbenum(full_name)
    return function(_, enum_name)
        local enum_val = pb_enum_id(full_name, enum_name)
        if not enum_val then
            log_warn("[pbenum] no enum %s.%s", full_name, enum_name)
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
    local proto_isreq = sends_with(proto_name, "_req")
    if proto_isreq or sends_with(proto_name, "_res") or sends_with(proto_name, "_ntf") then
        local package_name = tunpack(ssplit(full_name, "%."))
        local msg_name = "NID_" .. supper(proto_name)
        local enum_type = package_name .. ".NCmdId"
        local msg_id = pb_enum_id(enum_type, msg_name)
        if msg_id then
            self.pb_names[msg_id] = msg_name
            self.pb_indexs[msg_id] = { id = msg_id, name = full_name }
            self.pb_indexs[msg_name] = { id = msg_id, name = full_name }
            if proto_isreq then
                local msg_res_name = msg_name:sub(0, -2) .. "S"
                local msg_res_id = pb_enum_id(enum_type, msg_res_name)
                if msg_res_id then
                    self.pb_callbacks[msg_id] = msg_res_id
                end
            end
            return
        end
        log_warn("[ProtobufMgr][define_command] proto_name: [%s] can't find msg enum:[%s] !", proto_name, msg_name)
    end
end

function ProtobufMgr:register(doer, pb_name, callback)
    local proto = self.pb_indexs[pb_name]
    if not proto then
        log_warn("[ProtobufMgr][register] proto_name: [%s] can't find!", pb_name)
        return
    end
    event_mgr:add_cmd_listener(doer, proto.id, callback)
end

-- 重新加载
function ProtobufMgr:on_service_hotfix()
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
