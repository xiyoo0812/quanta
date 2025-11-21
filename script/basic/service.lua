--service.lua
--每个服务进程都有一个唯一的进程id，由4部分组成
--1、分组信息 0-63
--2、分区信息 0-1023
--3、服务类型 0-63
--4、实例编号 0-1023
--变量说明
--id：          进程id      32位数字
--group：       分组信息    0-63
--index：       实例编号    0-1023
--region:       分区信息    0-1023
--servcie:      服务类型    0-63
--node_id:      节点服务id  32位数字
--name:         服务名      lobby.1

local sformat       = string.format

--服务组常量
local SERVICES      = quanta.init("SERVICES")
local SERVICE_NAMES = quanta.init("SERVICE_NAMES")

service = {}
function service.make_node()
    quanta.node_info = {
        id = quanta.id,
        name = quanta.name,
        host = quanta.host,
        port = quanta.index,
        index = quanta.index,
        region = quanta.region,
        cluster = quanta.cluster,
        service = quanta.service,
        service_name = quanta.service_name
    }
end

function service.modify_id(id)
    quanta.node_info.id = id
    quanta.id = id
end

function service.modify_host(port, domain)
    quanta.node_info.port = port or quanta.index
    quanta.node_info.host = domain or quanta.host
end

function service.modify_option(val)
    quanta.node_info.option = val
end

function service.init()
    --加载服务配置
    local config_mgr = quanta.get("config_mgr")
    local service_db = config_mgr:init_enum_table("service", "Service", "id")
    for _, conf in service_db:iterator() do
        if conf.enable then
            SERVICE_NAMES[conf.id] = conf.name
        end
        SERVICES[conf.name] = conf.id
    end
    --初始化服务信息
    local index = environ.number("QUANTA_INDEX", 1)
    local cluster = environ.number("QUANTA_CLUSTER", 1)
    local region = environ.number("QUANTA_REGION", 1)
    local service_name = environ.get("QUANTA_SERVICE")
    local service_id = SERVICES[service_name]
    quanta.index = index
    quanta.region = region
    quanta.cluster = cluster
    quanta.service = service_id
    quanta.service_name = service_name
    quanta.host = environ.get("QUANTA_HOST_IP")
    quanta.order = environ.number("QUANTA_PORT", 1)
    quanta.id = service.make_sid(service_id, index)
    quanta.name = sformat("%s-%s", service_name, index)
    quanta.env = environ.get("QUANTA_ENVIRON", "develop")
    service.make_node()
end

--生成服务id
function service.make_sid(service, index)
    return (service << 16) | index
end

function service.services()
    return SERVICE_NAMES
end

--节点id获取服务id
function service.get_service(quanta_id)
    return (quanta_id >> 16) & 0xff
end

--节点id获取服务index
function service.get_index(quanta_id)
    return quanta_id & 0x3ff
end

--节点id转服务名
function service.id2name(quanta_id)
    return SERVICE_NAMES[quanta_id >> 16]
end

--服务id转服务名
function service.sid2name(service_id)
    return SERVICE_NAMES[service_id]
end

--服务名转服务id
function service.name2sid(name)
    return SERVICES[name]
end