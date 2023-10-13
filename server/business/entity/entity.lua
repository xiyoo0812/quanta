--entity.lua
local log_warn      = logger.warn

local AttrComponent = import("business/component/attr_component.lua")
local EvtComponent  = import("business/component/event_component.lua")

local Entity = class(nil, AttrComponent, EvtComponent)

local prop = property(Entity)
prop:reader("id")                       --id
prop:accessor("dynamic", false) --dynamic
prop:accessor("release", false) --release
prop:accessor("active_time", 0) --active_time
prop:accessor("load_success", false)    --load_success

function Entity:__init(id)
    self.id = id
end

function Entity:is_player()
    return false
end

function Entity:is_npc()
    return false
end

function Entity:is_monster()
    return false
end

function Entity:is_resource()
    return false
end

function Entity:can_relive()
    return true
end

-- 初始化
function Entity:setup(conf)
    if not self:load(conf) then
        log_warn("[Entity][setup] entity {} load faild!", self.id)
        return false
    end
    local setup_ok = self:collect("_setup")
    if not setup_ok then
        log_warn("[Entity][setup] entity {} setup faild!", self.id)
        return setup_ok
    end
    return setup_ok
end

--load
function Entity:load(conf)
    return true
end

--check
function Entity:check()
    return true
end

--update
function Entity:update(now)
    if self:check(now) then
        self:invoke("_update", now)
    end
end

--unload
function Entity:unload()
end

--destory
function Entity:destory()
    self:unload()
end

--reset
function Entity:reset()
    self:unload()
    self.dynamic = false
    self.release = false
    self.active_time = 0
    self.load_success = false
end

return Entity
