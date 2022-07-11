--attribute_sync.lua
local log_err           = logger.err
local log_info          = logger.info
local log_debug         = logger.debug
local qenum             = quanta.enum
local qfailed           = quanta.failed
local get_service       = service.get_service

local event_mgr         = quanta.get("event_mgr")
local router_mgr        = quanta.get("router_mgr")
local player_mgr        = quanta.get("player_mgr")
local config_mgr        = quanta.get("config_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")

local FRAME_SUCCESS     = protobuf_mgr:error_code("FRAME_SUCCESS")
local ROLE_NOT_EXIST    = protobuf_mgr:error_code("LOGIN_ROLE_NOT_EXIST")

local AttributeSync = singleton()
local prop = property(AttributeSync)
prop:reader("sync_agents", {})
prop:reader("sync_attrs", {})

--委托回调
function AttributeSync:__init()
    --注册通知
    event_mgr:add_trigger(self, "on_attr_changed")
    --注册rpc
    event_mgr:add_listener(self, "rpc_attr_writeback")
    --初始化属性
    config_mgr:init_enum_table("attribute", "AttrID", "id")
end

--初始化需要同步的属性
function AttributeSync:setup_sync_attrs(service_id, attr_db)
    local sync_attrs = self.sync_attrs
    for _, attr in attr_db:iterator() do
        if not sync_attrs[service_id] then
            sync_attrs[service_id] = {}
        end
        local attr_id = qenum("AttrID", attr.key)
        sync_attrs[service_id][attr_id] = true
    end
end

--打开同步
function AttributeSync:open_sync_attr(player, player_id, target_id)
    local attrs = {}
    local sync_agents = self.sync_agents
    local service_id = get_service(target_id)
    for attr_id in pairs(self.sync_attrs[service_id]) do
        if not sync_agents[player_id] then
            sync_agents[player_id] = {}
        end
        if not sync_agents[player_id][attr_id] then
            sync_agents[player_id][attr_id] = {}
        end
        sync_agents[player_id][attr_id][target_id] = true
        attrs[attr_id] = player:get_attr(attr_id)
    end
    --初始化属性同步
    local ok, code = router_mgr:call_target(target_id, "rpc_attr_setup", player_id, attrs)
    if not ok or qfailed(code) then
        log_err("[AttributeSync][open_sync_attr] setup failed attrs=%s, player_id=%s, code=%s", attrs, player_id, code)
        return false
    end
    log_info("[AttributeSync][open_sync_attr] setup success attrs=%s, player_id=%s", attrs, player_id)
    return true
end

--关闭同步
function AttributeSync:close_sync_attr(player_id, target_id)
    local sync_attrs = self.sync_agents[player_id] or {}
    for _, agents in pairs(sync_attrs) do
        agents[target_id] = nil
    end
end

--属性回写
function AttributeSync:rpc_attr_writeback(player_id, attr_id, value, source_id)
    local player  = player_mgr:get_entity(player_id)
    if not player then
        log_err("[AttributeSync][rpc_attr_writeback] player not exist attr_id=%s, player_id=%s", attr_id, player_id)
        return ROLE_NOT_EXIST
    end
    player:set_attr(attr_id, value, source_id)
    log_debug("[AttributeSync][rpc_attr_writeback] success! attr_id=%s, player_id=%s", attr_id, player_id)
    return FRAME_SUCCESS
end

--属性更新
function AttributeSync:on_attr_changed(entity, attr, attr_id, source_id)
    if not entity:is_attr_sync() then
        return
    end
    local value = attr.value
    local quanta_id = quanta.id
    local player_id = entity:get_id()
    local sync_attrs = self.sync_agents[player_id] or {}
    for target_id in pairs(sync_attrs[attr_id] or {}) do
        if source_id ~= target_id then
            local ok, code =  router_mgr:call_target(target_id, "rpc_attr_sync", player_id, attr_id, value, quanta_id)
            if not ok or qfailed(code) then
                log_err("[AttributeSync][on_attr_changed] sync failed attr_id=%s, player_id=%s, code=%s", attr_id, player_id, code)
            end
        end
    end
end

quanta.attr_sync = AttributeSync()

return AttributeSync
