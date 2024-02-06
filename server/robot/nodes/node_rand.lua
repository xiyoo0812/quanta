--node_rand.lua
local log_warn  = logger.warn
local makechan  = quanta.make_channel

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeRand = class(NodeBase)
local prop = property(NodeRand)
prop:reader("channel", nil) --channel

function NodeRand:__init(case)
end

function NodeRand:on_load(conf)
    self.channel = makechan("node")
    self.failed = conf.result.failed
    self.success = conf.result.success
    return true
end

function NodeRand:go_next()
    if self.result then
        self.case:run_next(self.success)
    else
        self.case:run_next(self.failed)
    end
end

function NodeRand:on_action()
    local role = self.actor
    local cond = self:call_script(self.cond)
    if cond == nil then
        log_warn("[NodeRand][on_action] robot:{} cond {} id null", role.open_id, self.cond)
        self:failed("cond error")
        return false
    end
    self.result = cond
    return true
end

return NodeRand
