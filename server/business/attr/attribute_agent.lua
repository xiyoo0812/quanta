--attribute_agent.lua
local log_err           = logger.err
local log_info          = logger.info
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
    event_mgr:add_trigger(self, "on_attr_changed")
    --注册rpc
    event_mgr:add_listener(self, "rpc_attr_sync")
    event_mgr:add_listener(self, "rpc_attr_setup")
    --初始化属性配置
    config_mgr:init_enum_table("attribute", "AttrID", "id")
end

--本地消息
-------------------------------------------------------------------------
--属性回写
function AttributeAgent:on_attr_changed(entity, attr, attr_id, source_id)
    --source_id存在说明是同步修改，否则是本地修改
    if source_id or (not entity:is_attr_sync()) then
        return
    end
    local player_id = entity:get_id()
    local lobby_id = entity:get_lobby()
    local ok, code = router_mgr:call_target(lobby_id, "rpc_attr_writeback", player_id, attr_id, attr.value, quanta.id)
    if not ok or qfailed(code) then
        log_err("[AttributeAgent][on_attr_changed] writeback failed attr=%s, player=%s, code=%s", attr_id, player_id, code)
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
    player:set_attr_sync(true)
    player:set_load_success(true)
    log_info("[AttributeAgent][rpc_attr_setup] success player_id=%s, attrs=%s", player_id, attrs)
    event_mgr:notify_trigger("on_load_success", player, player_id)
    return FRAME_SUCCESS
end

--属性更新
function AttributeAgent:rpc_attr_sync(player_id, attr_id, value, source_id)
    local player  = player_mgr:get_entity(player_id)
    if not player then
        log_err("[AttributeAgent][rpc_attr_sync] player not exist attr_id=%s, player_id=%s", attr_id, player_id)
        return ROLE_NOT_EXIST
    end
    player:set_attr(attr_id, value, source_id)
    log_debug("[AttributeAgent][rpc_attr_sync] success player_id=%s, attr=(%s-%s)", player_id, attr_id, value)
    return FRAME_SUCCESS
end

quanta.attr_agent= AttributeAgent()

return AttributeAgent
