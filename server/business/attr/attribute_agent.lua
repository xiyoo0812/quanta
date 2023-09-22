--attribute_agent.lua
local log_err           = logger.err
local log_debug         = logger.debug
local qfailed           = quanta.failed

local event_mgr         = quanta.get("event_mgr")
local player_mgr        = quanta.get("player_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local FRAME_SUCCESS     = protobuf_mgr:error_code("FRAME_SUCCESS")
local ROLE_NOT_EXIST    = protobuf_mgr:error_code("LOGIN_ROLE_NOT_EXIST")

local AttributeAgent = singleton()

--委托回调
function AttributeAgent:__init()
    --注册rpc
    event_mgr:add_listener(self, "rpc_attr_relay")
end

--属性加载
function AttributeAgent:load_attrs(player, attrs)
    player:load_attrs(attrs)
    player:set_wbackable(true)
    player:set_relayable(false)
    player:watch_event(self, "on_attr_writeback")
end

--本地消息
-------------------------------------------------------------------------
--属性回写
function AttributeAgent:on_attr_writeback(player, player_id)
    local write_attrs = player:get_write_attrs()
    local ok, code = player:call_lobby("rpc_attr_writeback", write_attrs, quanta.service)
    if qfailed(code, ok) then
        log_err("[AttributeAgent][on_attr_writeback] writeback failed attrs={}, player={}, code={}", write_attrs, player_id, code)
    end
    player:set_write_attrs({})
end

--rpc协议
-------------------------------------------------------------------------
--属性更新
function AttributeAgent:rpc_attr_relay(player_id, attrs, service_id)
    local player  = player_mgr:get_entity(player_id)
    if not player then
        log_err("[AttributeAgent][rpc_attr_relay] player not exist attrs={}, player_id={}", attrs, player_id)
        return ROLE_NOT_EXIST
    end
    for attr_id, value in pairs(attrs) do
        player:set_attr(attr_id, value, service_id)
    end
    log_debug("[AttributeAgent][rpc_attr_relay] success player_id={}, attrs={}", player_id, attrs)
    return FRAME_SUCCESS
end

quanta.attr_agent = AttributeAgent()

return AttributeAgent
