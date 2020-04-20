--每个服务进程都有一个唯一的服务标识,由服务分组(group)和服务索引(index)两部分构成
--有三种形式:
--servcie_id(string): 2.1
--service_id(number): 131073
--service_name: lobby.1
--在上面的示例中,服务id 2.1中的2表明服务分组(group)为2(lobby),实例编号(index)为1
local ssub      = string.sub
local sfind     = string.find
local sformat   = string.format
local tonumber  = tonumber

local service_groups =
{
    router      = 1,
    lobby       = 2,
    dbagent     = 3,
    dirsvr      = 4,
    matchsvr    = 5,
    indexsvr    = 6,
    roomsvr     = 7,
    admin       = 8,
    logagent    = 9,
    dscenter    = 10,
    dsagent     = 11,
    httpsvr     = 12,
    datasvr     = 13,
    test        = 14,
    robot       = 15,
    monitor     = 16,
    dsreport    = 17,
    teamsvr     = 18,
    collectsvr  = 19,

    --平台相关
    gateway     = 31,
    platform    = 32,
}

local service_names =
{
    [service_groups.router]     = "router",

    [service_groups.lobby]      = "lobby",
    [service_groups.dbagent]    = "dbagent",
    [service_groups.dirsvr]     = "dirsvr",
    [service_groups.matchsvr]   = "matchsvr",
    [service_groups.indexsvr]   = "indexsvr",
    [service_groups.roomsvr]    = "roomsvr",
    [service_groups.logagent]   = "logagent",
    [service_groups.httpsvr]    = "httpsvr",
    [service_groups.datasvr]    = "datasvr",
    [service_groups.teamsvr]    = "teamsvr",
    [service_groups.collectsvr] = "collectsvr",

    [service_groups.dscenter]   = "dscenter",
    [service_groups.dsagent]    = "dsagent",
    [service_groups.dsreport]   = "dsreport",

    [service_groups.admin]      = "admin",
    [service_groups.monitor]    = "monitor",
    [service_groups.test]       = "test",
    [service_groups.robot]      = "robot",

    [service_groups.gateway]    = "gateway",
    [service_groups.platform]   = "platform",
}

service = {}
service.groups = service_groups

function service.make_id(group, index)
    return (group << 16) | index
end

-- max : 255
function service.get_group(sid)
    return (sid >> 16) & 0xff
end

function service.get_name_by_id(sid)
    return service_names[sid >> 16]
end

function service.get_name(group)
    return service_names[group]
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
    return sformat("%s_%s", service_names[group], index)
end

function service.name2id(name)
    local pos = sfind(name, "_")
    local gname = ssub(name, 1, pos - 1)
    local index = ssub(name, pos + 1, #name)
    local group = service_groups[gname]
    return service.make_id(group, tonumber(index))
end

function service.get_group_by_name(name)
    return service_groups[name]
end
