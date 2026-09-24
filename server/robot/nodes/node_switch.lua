--node_switch.lua
local log_warn  = logger.warn

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeSwitch = class(NodeBase)
local prop = property(NodeSwitch)
prop:reader("inputs", nil)      --inputs
prop:reader("targets", {})      --targets

function NodeSwitch:__init(case)
end

function NodeSwitch:on_load(conf)
    self.inputs = conf.inputs
    for _, item in pairs(conf.targets or {}) do
        self.targets[item[1]] = item[2]
    end
    return true
end

function NodeSwitch:on_start()
    local role = self.actor
    local skey = self:read_input(self.inputs.key)
    if skey == nil then
        log_warn("[NodeSwitch][on_start] robot:{} switch {} key read failed", role.open_id, self.name)
        self:failed("switch key read failed")
        return false
    end
    local branch = self.targets[skey]
    if not branch then
        log_warn("[NodeSwitch][on_start] robot:{} switch {} key {} not valid", role.open_id, self.name, skey)
        self:failed("switch not valid")
        return false
    end
    self.next = branch
    return true
end

return NodeSwitch
