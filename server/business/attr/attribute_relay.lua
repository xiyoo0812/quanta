--attribute_relay.lua
local log_err           = logger.err
local log_debug         = logger.debug
local tunpack           = table.unpack
local qenum             = quanta.enum
local qfailed           = quanta.failed

local event_mgr         = quanta.get("event_mgr")
local player_mgr        = quanta.get("player_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local FRAME_SUCCESS     = protobuf_mgr:error_code("FRAME_SUCCESS")
local ROLE_NOT_EXIST    = protobuf_mgr:error_code("LOGIN_ROLE_NOT_EXIST")

local AttributeRelay = singleton()
local prop = property(AttributeRelay)
prop:reader("relay_attrs", {})

--委托回调
function AttributeRelay:__init()
    --注册rpc
    event_mgr:add_listener(self, "rpc_attr_writeback")
end

--打开共享属性
function AttributeRelay:open_share_attr(player, attr_db, service_name)
    --注册属性转发
    player:watch_event(self, "on_attr_relay")
    --属性绑定
    for _, attr in attr_db:iterator() do
        local attr_id = qenum("AttrID", attr.key)
        if attr.share then
            player:bind_attr(attr_id, attr, service_name)
        end
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
    local relay_attrs = {}
    local share_attrs = player:load_share_attrs()
    for attr_id, args in pairs(share_attrs) do
        local value, services = tunpack(args)
        for service_name in pairs(services) do
            if not relay_attrs[service_name] then
                relay_attrs[service_name] = {}
            end
            relay_attrs[service_name][attr_id] = value
        end
    end
    local success = true
    for service_name, attrs in pairs(relay_attrs) do
        local ok, code =  player:call_service(service_name, "rpc_attr_relay", attrs, quanta.service)
        if qfailed(code, ok) then
            log_err("[AttributeRelay][on_attr_relay] sync failed attrs={}, player_id={}, code={}", attrs, player_id, code)
            success = false
        end
    end
    if not success then
        player:merge_share_attrs(share_attrs)
    end
end

quanta.attr_relay = AttributeRelay()

return AttributeRelay
