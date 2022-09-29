--attribute_agent.lua
local log_err           = logger.err
local log_debug         = logger.debug
local qfailed           = quanta.failed

local event_mgr         = quanta.get("event_mgr")
local config_mgr        = quanta.get("config_mgr")
local router_mgr        = quanta.get("router_mgr")
local player_mgr        = quanta.get("player_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local FRAME_SUCCESS     = protobuf_mgr:error_code("FRAME_SUCCESS")
local ROLE_NOT_EXIST    = protobuf_mgr:error_code("LOGIN_ROLE_NOT_EXIST")


local AttributeAgent = singleton()
local prop = property(AttributeAgent)
prop:reader("agents", {})

--委托回调
function AttributeAgent:__init()
    --注册消息
    event_mgr:add_trigger(self, "on_attr_writeback")
    event_mgr:add_trigger(self, "on_scene_changed")
    --注册rpc
    event_mgr:add_listener(self, "rpc_attr_relay")
    event_mgr:add_listener(self, "rpc_attr_setup")
    --初始化属性配置
    config_mgr:init_enum_table("attribute", "AttrID", "id")
end

--本地消息
-------------------------------------------------------------------------
--属性回写
function AttributeAgent:on_attr_writeback(player_id, player)
    local write_attrs = player:get_write_attrs()
    local lobby_id = player:find_passkey("lobby")
    local ok, code = router_mgr:call_target(lobby_id, "rpc_attr_writeback", player_id, write_attrs, quanta.id)
    if not ok or qfailed(code) then
        log_err("[AttributeAgent][on_attr_writeback] writeback failed attrs=%s, player=%s, code=%s", write_attrs, player_id, code)
    end
    player:set_write_attrs({})
end

--属性回写
function AttributeAgent:on_scene_changed(player, player_id)
    local write_attrs = {}
    local AttrID = enum("AttrID")
    for attr_id = AttrID.ATTR_MAP_ID, AttrID.ATTR_POS_Z do
        write_attrs[attr_id] = player:get_attr(attr_id)
    end
    local lobby_id = player:find_passkey("lobby")
    local ok, code = router_mgr:call_target(lobby_id, "rpc_attr_writeback", player_id, write_attrs, quanta.id)
    if not ok or qfailed(code) then
        log_err("[AttributeAgent][on_scene_changed] writeback failed attr=%s, player=%s, code=%s", write_attrs, player_id, code)
    end
end

--rpc协议
-------------------------------------------------------------------------
--属性更新
function AttributeAgent:rpc_attr_setup(player_id, attrs)
    local player  = player_mgr:get_entity(player_id)
    if not player then
        log_err("[AttributeAgent][rpc_attr_setup] player not exist, player_id=%s", player_id)
        return ROLE_NOT_EXIST
    end
    for attr_id, value in pairs(attrs) do
        player:set_attr(attr_id, value)
    end
    player:set_wbackable(true)
    player:set_relayable(false)
    log_debug("[AttributeAgent][rpc_attr_setup] success player_id=%s, attrs=%s", player_id, attrs)
    event_mgr:notify_trigger("on_load_success", player, player_id)
    return FRAME_SUCCESS
end

--属性更新
function AttributeAgent:rpc_attr_relay(player_id, attrs, source_id)
    local player  = player_mgr:get_entity(player_id)
    if not player then
        log_err("[AttributeAgent][rpc_attr_relay] player not exist attrs=%s, player_id=%s", attrs, player_id)
        return ROLE_NOT_EXIST
    end
    for attr_id, value in pairs(attrs) do
        player:set_attr(attr_id, value, source_id)
    end
    log_debug("[AttributeAgent][rpc_attr_relay] success player_id=%s, attrs=%s", player_id, attrs)
    return FRAME_SUCCESS
end

quanta.attr_agent= AttributeAgent()

return AttributeAgent
