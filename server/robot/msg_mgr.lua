-- robot_mgr.lua

local pb_enum_id   = protobuf.enum
local supper       = string.upper
local tunpack      = table.unpack
local tcopy        = qtable.copy

local protobuf_mgr = quanta.get("protobuf_mgr")

local MsgMgr       = singleton()
local prop         = property(MsgMgr)
prop:reader("accord_req_group", {}) -- 协议分组(解析proto)
prop:reader("accord_res_group", {}) -- 协议分组(解析proto)
prop:reader("accord_ntf_group", {}) -- 协议分组(解析proto)
prop:reader("accord_group", {})     -- 协议分组(解析proto)

function MsgMgr:__init()
    self:init_accord()
end

function MsgMgr:ssplit(str, token)
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

function MsgMgr:sends_with(str, ending)
    return str:sub(- #ending) == ending
end

-- 初始化协议数据
function MsgMgr:init_accord()
    for full_name, proto_name, type in protobuf.types() do
        if type == "message" then
            local package_name = tunpack(self:ssplit(full_name, "%."))
            local enum_type = package_name .. ".NCmdId"
            local msg_name = "NID_" .. supper(proto_name)
            local msg_id = pb_enum_id(enum_type, msg_name)
            if msg_id then
                local fields = {}
                for name, _, typ in protobuf.fields(full_name) do
                    fields[name] = (typ == "string") and "xxx" or 0
                end
                local group = string.sub(msg_name, 1, string.find(msg_name, "_", string.find(msg_name, "_") + 1) - 1)
                if group then
                    if not self.accord_group[group] then
                        self.accord_group[group] = {}
                    end
                    self.accord_group[group][msg_name] = {
                        msg_id = msg_id,
                        name = msg_name,
                        fields = fields,
                        type = string.sub(proto_name, -3)
                    }
                end
            end
        end
    end
end

-- 转换字段
function MsgMgr:convert_fields(struct, data)
    if not data then
        return
    end
    for key, field_type in pairs(struct) do
        local value = data[key]
        if type(field_type) == "table" then
            self:convert_fields(field_type, value)
        elseif field_type == "uint64" then
            data[key] = tostring(value)
        end
    end
end

-- 返回协议结构
function MsgMgr:msg_struct(cmd_id)
    local struct = {}
    local name = protobuf_mgr:msg_name(cmd_id)
    for key, _, type in protobuf.fields(name) do
        struct[key] = type
    end
    return struct
end

-- 参数转换
function MsgMgr:args_convert(cmd_id, data)
    if cmd_id == 1001 then
        return
    end
    local c_data = tcopy(data)
    -- 获取协议结构
    local struct = self:msg_struct(cmd_id)
    -- 转换参数字段
    if struct then
        self:convert_fields(struct, c_data)
    end
    return c_data
end

quanta.msg_mgr = MsgMgr()

return MsgMgr
