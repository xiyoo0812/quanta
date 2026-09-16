--node_switch.lua
local log_warn  = logger.warn

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeSwitch = class(NodeBase)
local prop = property(NodeSwitch)
prop:reader("inputs", nil)      --inputs
prop:reader("targets", nil)     --targets
prop:reader("branch", nil)      --branch

function NodeSwitch:__init(case)
end

function NodeSwitch:on_load(conf)
    self.inputs = conf.inputs
    for _, item in pairs(conf.targets or {}) do
        self.targets[item[1]] = item[2]
    end
    return true
end

function NodeSwitch:go_next()
    if self.branch then
        self.case:run_next(self.branch)
    end
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
    self.branch = branch
    return true
end

return NodeSwitch
