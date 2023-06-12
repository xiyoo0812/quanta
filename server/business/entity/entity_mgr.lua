--entity_mgr.lua

local log_info      = logger.info

local update_mgr    = quanta.get("update_mgr")

local EntityMgr = singleton()
local prop = property(EntityMgr)
prop:reader("wheel_cur", 1)
prop:reader("entity_map", nil)

function EntityMgr:__init()
    local WheelMap = import("container/wheel_map.lua")
    self.entity_map = WheelMap(100)
    update_mgr:attach_frame(self)
end

function EntityMgr:on_frame()
    local now = quanta.now
    local del_entitys = {}
    local fiter, wheel = self.entity_map:wheel_iterator(self.wheel_cur)
    for entity_id, entity in fiter do
        entity:update(now)
        if entity:is_release() then
            del_entitys[entity_id] = entity
        end
    end
    self.wheel_cur = wheel
    for entity_id, entity in pairs(del_entitys) do
        self:remove_entity(entity, entity_id)
    end
end

--实体被消耗
function EntityMgr:on_destory(entity_id, entity)
end

-- 设置实体
function EntityMgr:add_entity(entity_id, entity)
    log_info("[EntityMgr][add_entity] entity_id=%s", entity_id)
    self.entity_map:set(entity_id, entity)
end

-- 移除实体
function EntityMgr:remove_entity(entity, entity_id)
    log_info("[EntityMgr][remove_entity] entity_id=%s", entity_id)
    entity:destory()
    self.entity_map:set(entity_id, nil)
    self:on_destory(entity_id, entity)
end

--查找实体
function EntityMgr:get_entity(entity_id)
    if entity_id then
        return self.entity_map:get(entity_id)
    end
end

--获取实体数量
function EntityMgr:size()
    return self.entity_map:get_count()
end

--查找实体
function EntityMgr:iterator()
    return self.entity_map:iterator()
end

return EntityMgr
