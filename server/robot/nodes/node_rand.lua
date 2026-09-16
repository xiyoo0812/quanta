--node_rand.lua
local log_warn  = logger.warn
local mrandom   = math.random

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeRand = class(NodeBase)
local prop = property(NodeRand)
prop:reader("targets", nil)     --targets
prop:reader("branch", nil)      --branch

function NodeRand:__init(case)
end

function NodeRand:on_load(conf)
    self.targets = conf.targets or {}
    return true
end

function NodeRand:go_next()
    if self.branch then
        self.case:run_next(self.branch)
    end
end

function NodeRand:on_start()
    local role = self.actor
    local targets = self.targets
    if #targets == 0 then
        log_warn("[NodeRand][on_start] robot:{} rand {} targets is empty", role.open_id, self.name)
        self:failed("rand targets is empty")
        return false
    end
    self.branch = targets[mrandom(#targets)]
    return true
end

return NodeRand
