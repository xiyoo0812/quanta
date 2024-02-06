--node_cond.lua
local log_warn  = logger.warn

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeCond = class(NodeBase)
local prop = property(NodeCond)
prop:reader("cond", nil)        --cond
prop:reader("success", nil)     --success
prop:reader("failed", nil)      --failed
prop:reader("result", false)    --result

function NodeCond:__init(case)
end

function NodeCond:on_load(conf)
    self.cond = conf.cond
    self.failed = conf.result.failed
    self.success = conf.result.success
    return true
end

function NodeCond:go_next()
    if self.result then
        self.case:run_next(self.success)
    else
        self.case:run_next(self.failed)
    end
end

function NodeCond:on_action()
    local role = self.actor
    local cond = self:call_script(self.cond)
    if cond == nil then
        log_warn("[NodeCond][on_action] robot:{} cond {} id null", role.open_id, self.cond)
        self:failed("cond error")
        return false
    end
    self.result = cond
    return true
end

return NodeCond
