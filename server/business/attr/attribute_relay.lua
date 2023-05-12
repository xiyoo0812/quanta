--attribute_relay.lua
local log_err           = logger.err
local log_info          = logger.info
local log_debug         = logger.debug
local tunpack           = table.unpack
local qenum             = quanta.enum
local qfailed           = quanta.failed
local get_service       = service.get_service

local event_mgr         = quanta.get("event_mgr")
local router_mgr        = quanta.get("router_mgr")
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
function AttributeRelay:setup_relay_attrs(service_id, attr_db)
    local relay_attrs = self.relay_attrs
    for _, attr in attr_db:iterator() do
        if not relay_attrs[service_id] then
            relay_attrs[service_id] = {}
        end
        local attr_id = qenum("AttrID", attr.key)
        relay_attrs[service_id][attr_id] = true
    end
end

--打开同步
function AttributeRelay:open_relay_attr(player, player_id, target_id)
    local attrs = {}
    local relay_agents = self.relay_agents
    local service_id = get_service(target_id)
    for attr_id in pairs(self.relay_attrs[service_id]) do
        if not relay_agents[player_id] then
            relay_agents[player_id] = {}
        end
        if not relay_agents[player_id][target_id] then
            relay_agents[player_id][target_id] = {}
        end
        relay_agents[player_id][target_id][attr_id] = true
        attrs[attr_id] = player:get_attr(attr_id)
    end
    --初始化属性同步
    local ok, code = router_mgr:call_target(target_id, "rpc_attr_setup", player_id, attrs)
    if qfailed(code, ok) then
        log_err("[AttributeRelay][open_relay_attr] setup failed attrs=%s, player_id=%s, code=%s", attrs, player_id, code)
        return false
    end
    log_info("[AttributeRelay][open_relay_attr] setup success player_id=%s", player_id)
    player:add_trigger(self, "on_attr_relay")
    return true
end

--关闭同步
function AttributeRelay:close_relay_attr(player_id, target_id)
    local relay_agents = self.relay_agents[player_id]
    if relay_agents then
        relay_agents[target_id] = nil
    end
end

--属性回写
function AttributeRelay:rpc_attr_writeback(player_id, attrs, source_id)
    local player  = player_mgr:get_entity(player_id)
    if not player then
        log_err("[AttributeRelay][rpc_attr_writeback] player not exist attrs=%s, player_id=%s", attrs, player_id)
        return ROLE_NOT_EXIST
    end
    for attr_id, value in pairs(attrs) do
        player:set_attr(attr_id, value, source_id)
    end
    log_debug("[AttributeRelay][rpc_attr_writeback] success! attrs=%s, player_id=%s", attrs, player_id)
    return FRAME_SUCCESS
end

--属性转发
function AttributeRelay:on_attr_relay(player_id, player)
    local quanta_id = quanta.id
    local relay_attrs = player:get_relay_attrs()
    local relay_agents = self.relay_agents[player_id] or {}
    for target_id, agent_attrs in pairs(relay_agents) do
        local attrs = {}
        for attr_id, args in pairs(relay_attrs) do
            if agent_attrs[attr_id] then
                local value, source_id = tunpack(args)
                if source_id ~= target_id then
                    attrs[attr_id] = value
                end
            end
        end
        if next(attrs) then
            local ok, code =  router_mgr:call_target(target_id, "rpc_attr_relay", player_id, attrs, quanta_id)
            if qfailed(code, ok) then
                log_err("[AttributeRelay][on_attr_relay] sync failed attrs=%s, player_id=%s, code=%s", attrs, player_id, code)
            end
        end
    end
    player:set_relay_attrs({})
end

quanta.attr_relay = AttributeRelay()

return AttributeRelay
