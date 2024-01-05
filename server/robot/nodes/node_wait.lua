--node_wait.lua
local log_warn  = logger.warn

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeWait = class(NodeBase)
local prop = property(NodeWait)
prop:reader("time", 0)      --time
prop:reader("cond", nil)    --cond

function NodeWait:__init(case)
end

function NodeWait:on_load(conf)
    self.cond = conf.cond
    self.time = conf.time or 1000
    return true
end

function NodeWait:on_action()
    self:sleep(self.time)
    if self.cond then
        local cond = self:call_script(self.cond)
        if cond == nil then
            log_warn("[NodeWait][on_action] robot:{} cond {} id null", self.actor.open_id, self.cond)
            self:failed("cond error")
            return false
        end
        if not cond then
            return false
        end
    end
    return true
end

return NodeWait
