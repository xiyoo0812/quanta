--attribute_relay.lua
local log_err           = logger.err
local log_debug         = logger.debug
local tunpack           = table.unpack
local qenum             = quanta.enum
local qfailed           = quanta.failed
local sname2sid         = service.name2sid

local event_mgr         = quanta.get("event_mgr")
local player_mgr        = quanta.get("player_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local FRAME_SUCCESS     = protobuf_mgr:error_code("FRAME_SUCCESS")
local ROLE_NOT_EXIST    = protobuf_mgr:error_code("LOGIN_ROLE_NOT_EXIST")

local AttributeRelay = singleton()
local prop = property(AttributeRelay)
prop:reader("relay_agents", {})
prop:reader("relay_attrs", {})

--委托回调
function AttributeRelay:__init()
    --注册rpc
    event_mgr:add_listener(self, "rpc_attr_writeback")
end

--初始化需要同步的属性
function AttributeRelay:setup_relay_attrs(service_name, attr_db)
    local relay_attrs = self.relay_attrs
    for _, attr in attr_db:iterator() do
        if not relay_attrs[service_name] then
            relay_attrs[service_name] = {}
        end
        local attr_id = qenum("AttrID", attr.key)
        relay_attrs[service_name][attr_id] = true
    end
end

function AttributeRelay:open_relay_attr(player)
    --注册属性转发
    player:watch_event(self, "on_attr_relay")
end

function AttributeRelay:collect_relay_attr(player, player_id, service_name)
    local attrs = {}
    local relay_agents = self.relay_agents
    for attr_id in pairs(self.relay_attrs[service_name]) do
        if not relay_agents[player_id] then
            relay_agents[player_id] = {}
        end
        if not relay_agents[player_id][service_name] then
            relay_agents[player_id][service_name] = {}
        end
        relay_agents[player_id][service_name][attr_id] = true
        attrs[attr_id] = player:get_attr(attr_id)
    end
    return attrs
end

--关闭同步
function AttributeRelay:close_relay_attr(player_id, service_name)
    local relay_agents = self.relay_agents[player_id]
    if relay_agents then
        relay_agents[service_name] = nil
    end
end

--属性回写
function AttributeRelay:rpc_attr_writeback(player_id, attrs, service_id)
    local player  = player_mgr:get_entity(player_id)
    if not player then
        log_err("[AttributeRelay][rpc_attr_writeback] player not exist attrs={}, player_id={}", attrs, player_id)
        return ROLE_NOT_EXIST
    end
    for attr_id, value in pairs(attrs) do
        player:set_attr(attr_id, value, service_id)
    end
    log_debug("[AttributeRelay][rpc_attr_writeback] success! attrs={}, player_id={}", attrs, player_id)
    return FRAME_SUCCESS
end

--属性转发
function AttributeRelay:on_attr_relay(player, player_id)
    local relay_attrs = player:load_relay_attrs()
    local relay_agents = self.relay_agents[player_id] or {}
    for service_name, agent_attrs in pairs(relay_agents) do
        local attrs = {}
        local reply_service_id = sname2sid(service_name)
        for attr_id, args in pairs(relay_attrs) do
            if agent_attrs[attr_id] then
                local value, service_id = tunpack(args)
                if reply_service_id ~= service_id then
                    attrs[attr_id] = value
                end
            end
        end
        if next(attrs) then
            local ok, code =  player:call_service(service_name, "rpc_attr_relay", attrs, quanta.service)
            if qfailed(code, ok) then
                player:merge_relay_attrs(relay_attrs)
                log_err("[AttributeRelay][on_attr_relay] sync failed attrs={}, player_id={}, code={}", attrs, player_id, code)
            end
        end
    end
end

quanta.attr_relay = AttributeRelay()

return AttributeRelay
