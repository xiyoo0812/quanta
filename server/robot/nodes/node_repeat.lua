--node_repeat.lua
local log_warn  = logger.warn

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeRepeat = class(NodeBase)
local prop = property(NodeRepeat)
prop:reader("childs", {})   --childs

function NodeRepeat:__init(case)
end

function NodeRepeat:on_load(conf)
    self.cond = conf.cond
    self.failed = conf.result.failed
    self.success = conf.result.success
    return true
end

function NodeRepeat:go_next()
    if self.result then
        self.case:run_next(self.success)
    else
        self.case:run_next(self.failed)
    end
end

function NodeRepeat:on_action()
    local role = self.actor
    local cond = self:call_script(self.cond)
    if cond == nil then
        log_warn("[NodeRepeat][on_action] robot:{} cond {} id null", role.open_id, self.cond)
        self:failed("cond error")
        return false
    end
    self.result = cond
    return true
end

return NodeRepeat
