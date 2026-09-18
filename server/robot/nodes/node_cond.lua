--node_cond.lua
local log_debug = logger.debug
local log_warn  = logger.warn

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeCond = class(NodeBase)
local prop = property(NodeCond)
prop:reader("cond", nil)        --cond
prop:reader("success_node", nil)     --success
prop:reader("failed_node", nil)      --failed

function NodeCond:__init(case)
end

function NodeCond:on_load(conf)
    self.cond = conf.cond
    self.failed_node = conf.result.failed
    self.success_node = conf.result.success
    return true
end

function NodeCond:go_next()
    if self.result then
        self.case:run_next(self.success_node)
    else
        self.case:run_next(self.failed_node)
    end
end

function NodeCond:on_start()
    local role = self.actor
    local cond, err = self:call_script(self.cond)
    if cond == nil then
        log_warn("[NodeCond][on_start] robot:{} run node:{}'s cond {} call error: {}", role.open_id, self.name, self.cond, err)
        self:failed("cond call error: " .. err)
        return false
    end
    log_debug("[NodeCond][on_start] robot:{} run node:{}'s cond {} result: {}", role.open_id, self.name, self.cond, cond)
    self.result = cond
    return true
end

return NodeCond
