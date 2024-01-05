--node_goal.lua

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeGoal = class(NodeBase)
local prop = property(NodeGoal)
prop:reader("script", nil)    --script
prop:reader("outputs", nil) --outputs

function NodeGoal:__init(case)
end

function NodeGoal:on_load(conf)
    self.script = conf.script
    self.outputs = conf.outputs
    return true
end

function NodeGoal:on_action()
    self:write_outputs(self.outputs)
    self:run_script(self.script)
    return true
end

return NodeGoal
