--node_switch.lua
local log_warn  = logger.warn

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeSwitch = class(NodeBase)
local prop = property(NodeSwitch)
prop:reader("inputs", nil)      --inputs
prop:reader("targets", nil)     --targets
prop:reader("goal", nil)        --goal

function NodeSwitch:__init(case)
end

function NodeSwitch:on_load(conf)
    self.inputs = conf.inputs
    self.targets = conf.targets
    return true
end

function NodeSwitch:go_next()
    if self.goal then
        self.case:run_next(self.goal)
    end
end

function NodeSwitch:on_action()
    local role = self.actor
    local value = self:read_input("value")
    if value == nil then
        log_warn("[NodeSwitch][on_action] robot:{} switch value null", role.open_id)
        self:failed("switch null")
        return false
    end
    local goal = self.targets[value]
    if not goal then
        log_warn("[NodeSwitch][on_action] robot:{} switch value {} not valid", role.open_id, value)
        self:failed("switch not valid")
        return false
    end
    self.goal = goal
    return true
end

return NodeSwitch
