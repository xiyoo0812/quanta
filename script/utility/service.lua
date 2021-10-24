--每个服务进程都有一个唯一的服务标识,由服务(servcie)和服务索引(index)两部分构成
--有三种形式:
--servcie: lobby
--service_id: 131073
--service_nick: lobby.1
--在上面的示例中,服务id 2.1中的2表明服务分(servcie)为2(lobby),实例编号(index)为1
local tonumber      = tonumber
local ssub          = string.sub
local sfind         = string.find
local sformat       = string.format

local config_mgr    = quanta.get("config_mgr")
local service_db    = config_mgr:init_table("service", "id")

--服务组常量
local SERVICES      = _ENV.SERVICES or {}

service = {}

--定义服务器组
function service.init(name)
    for _, conf in service_db:iterator() do
        SERVICES[conf.name] = conf.id
    end
    return SERVICES[name]
end

--生成节点id
function service.make_id(service_name, index)
    local service_id = SERVICES[service_name]
    return (service_id << 16) | index
end

--生成节点nick
function service.make_nick(service, index)
    return sformat("%s_%s", service, index)
end

--节点id获取服务id
function service.id2sid(quanta_id)
    return (quanta_id >> 16) & 0xff
end

--节点id转服务名
function service.id2name(quanta_id)
    return service_db:find_value("name", quanta_id >> 16)
end

--服务id转服务名
function service.sid2name(service_id)
    return service_db:find_value("name", service_id)
end

--服务最大数量
function service.count(service_id)
    return service_db:find_value("count", service_id)
end

--服务是否启动路由
function service.router(service_id)
    return service_db:find_value("router", service_id)
end

--服务hash
function service.hash(service_id)
    local conf = service_db:find_one(service_id)
    return conf.count >= conf.hash and conf.hash or conf.count
end

--服务名转服务id
function service.name2sid(name)
    return SERVICES[name]
end

--节点id获取服务index
function service.id2index(quanta_id)
    return quanta_id & 0x3ff
end

--节点id转服务昵称
function service.id2nick(quanta_id)
    if quanta_id == nil or quanta_id == 0 then
        return "nil"
    end
    local index = quanta_id & 0x3ff
    local service_id = quanta_id >> 16
    local sname = service.sid2name(service_id)
    return sformat("%s_%s", sname, index)
end

--服务昵称转节点id
function service.nick2id(nick)
    local pos = sfind(nick, "_")
    local sname = ssub(nick, 1, pos - 1)
    local index = ssub(nick, pos + 1, #nick)
    return service.make_id(SERVICES[sname], tonumber(index))
end

--生成router_id
function service.router_id(host_id, index)
    local router_index = host_id << 8 | index
    return service.make_id("router", router_index)
end

