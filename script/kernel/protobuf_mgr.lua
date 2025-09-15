--protobuf_mgr.lua

local ipairs        = ipairs
local pcall         = pcall
local log_err       = logger.err
local log_warn      = logger.warn
local log_debug     = logger.debug
local env_get       = environ.get
local pb_enum_id    = protobuf.enum
local pb_decode     = protobuf.decode
local pb_encode     = protobuf.encode
local pb_bind_cmd   = protobuf.bind_cmd
local tunpack       = table.unpack
local supper        = string.upper
local ssplit        = string.split
local sends_with    = string.ends_with
local dgetinfo      = debug.getinfo
local setmetatable  = setmetatable

local event_mgr     = quanta.get("event_mgr")

local ProtobufMgr = singleton()
local prop = property(ProtobufMgr)
prop:reader("services", nil)
prop:reader("pb_indexs", {})
prop:reader("pb_callbacks", {})
prop:reader("allow_reload", false)

function ProtobufMgr:__init()
    self:load_protos()
    --监听热更新
    event_mgr:add_trigger(self, "on_reload")
end

--返回回调id
function ProtobufMgr:callback_id(cmd_id)
    local pb_cbid = self.pb_callbacks[cmd_id]
    if not pb_cbid then
        log_warn("[ProtobufMgr][callback_id] cmdid {} find callback_id is nil", cmd_id)
    end
    return pb_cbid
end

--返回协议名称
function ProtobufMgr:msg_name(pb_cmd)
    return self.pb_indexs[pb_cmd].name
end

function ProtobufMgr:msg_id(pb_cmd)
    local info = self.pb_indexs[pb_cmd]
    return info.id, info.cmd
end

function ProtobufMgr:get_service(service, method)
    if not self.services then
        self.services = protobuf.services()
    end
    local service_info = self.services[service]
    if not service_info then
        log_err("[ProtobufMgr][get_service] service not found: {}", service)
        return
    end
    if not service_info[method] then
        log_err("[ProtobufMgr][get_service] method not found: {}.{}", service, method)
        return
    end
    return service_info[method]
end

function ProtobufMgr:error_code(err_key)
    return self:enum("ErrorCode", err_key)
end

function ProtobufMgr:enum(ename, ekey)
    local lenum = ncmd_cs[ename]
    if not lenum then
        local info = dgetinfo(2, "S")
        log_warn("[ProtobufMgr][enum] {} not initial! source({}:{})", ename, info.short_src, info.linedefined)
        return
    end
    local value = lenum[ekey]
    if not value then
        local info = dgetinfo(2, "S")
        log_warn("[ProtobufMgr][enum] {}.{} not defined! source({}:{})", ename, ekey, info.short_src, info.linedefined)
        return
    end
    return value
end

function ProtobufMgr:load_file(file)
    protobuf.loadfile(file)
    log_debug("[ProtobufMgr][load_file] load pb file: {}", file)
end

--加载pb文件
function ProtobufMgr:load_protos()
    local proto_file = env_get("QUANTA_PROTO_FILE")
    if proto_file then
        self:load_file(proto_file)
        --注册枚举
        for _, name in pairs(protobuf.enums()) do
            self:define_enum(name)
        end
        --注册CMDID和PB的映射
        for full_name, name in pairs(protobuf.messages()) do
            self:define_command(full_name, name)
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
        log_err("[ProtobufMgr][encode] find proto failed! cmd:{}", pb_cmd)
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
        log_err("[ProtobufMgr][decode] find proto failed! cmd:{}", pb_cmd)
        return
    end
    local ok, pb_data = pcall(pb_decode, proto.name, pb_str)
    if ok then
        return pb_data, proto.name
    end
end

local function pbenum(full_name)
    return function(enum, enum_name)
        local enum_val = pb_enum_id(full_name, enum_name)
        if not enum_val then
            log_warn("[pbenum] no enum {}.{}", full_name, enum_name)
        end
        enum[enum_name] = enum_val
        return enum_val
    end
end

function ProtobufMgr:define_enum(full_name)
    local pb_enum = _G
    local nodes = ssplit(full_name, ".")
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
        local package_name = tunpack(ssplit(full_name, "."))
        local msg_name = "NID_" .. supper(proto_name)
        local enum_type = package_name .. ".NCmdId"
        local msg_id = pb_enum_id(enum_type, msg_name)
        if msg_id then
            local info = { id = msg_id, name = full_name, cmd = msg_name }
            self.pb_indexs[msg_id] = info
            self.pb_indexs[msg_name] = info
            if proto_isreq then
                local msg_res_name = msg_name:sub(0, -2) .. "S"
                local msg_res_id = pb_enum_id(enum_type, msg_res_name)
                if msg_res_id then
                    self.pb_callbacks[msg_id] = msg_res_id
                end
            end
            pb_bind_cmd(msg_id, msg_name, full_name)
            return
        end
        log_warn("[ProtobufMgr][define_command] proto_name: [{}] can't find msg enum:[{}] !", proto_name, msg_name)
    end
end

function ProtobufMgr:register(doer, pb_name, callback)
    local proto = self.pb_indexs[pb_name]
    if not proto then
        log_warn("[ProtobufMgr][register] proto_name: [{}] can't find!", pb_name)
        return
    end
    event_mgr:add_cmd_listener(doer, proto.id, callback)
end

-- 重新加载
function ProtobufMgr:on_reload()
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
