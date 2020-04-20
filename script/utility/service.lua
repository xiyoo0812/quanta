--每个服务进程都有一个唯一的服务标识,由服务分组(group)和服务索引(index)两部分构成
--有三种形式:
--servcie_id(string): 2.1
--service_id(number): 131073
--service_name: lobby.1
--在上面的示例中,服务id 2.1中的2表明服务分组(group)为2(lobby),实例编号(index)为1
local tonumber  = tonumber
local ssub      = string.sub
local sfind     = string.find
local sformat   = string.format
local log_warn  = logger.warn

--服务组常量
local GROUPS = {}
local GROUP_NAMES = {}

service = {}
service.groups = GROUPS

--定义服务器组
function service.define(group, group_name)
    if GROUP_NAMES[group] then
        log_warn("[service][define] redefine group: %d, name: %s", group, group_name)
    end
    GROUPS[group_name] = group
    GROUP_NAMES[group] = group_name
end

function service.make_id(group, index)
    return (group << 16) | index
end

-- max : 255
function service.get_group(sid)
    return (sid >> 16) & 0xff
end

function service.get_name_by_id(sid)
    return GROUP_NAMES[sid >> 16]
end

function service.get_name(group)
    return GROUP_NAMES[group]
end

-- max : 1023
function service.get_index(sid)
    return sid & 0x3ff
end

function service.id2name(sid)
    if sid == nil or sid == 0 then
        return "nil"
    end
    local group = sid >> 16
    local index = sid & 0x3ff
    return sformat("%s_%s", GROUP_NAMES[group], index)
end

function service.name2id(name)
    local pos = sfind(name, "_")
    local gname = ssub(name, 1, pos - 1)
    local index = ssub(name, pos + 1, #name)
    local group = GROUPS[gname]
    return service.make_id(group, tonumber(index))
end

function service.get_group_by_name(name)
    return GROUPS[name]
end
