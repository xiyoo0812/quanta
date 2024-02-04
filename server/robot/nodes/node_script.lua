--node_script.lua

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeScript = class(NodeBase)
local prop = property(NodeScript)
prop:reader("script", nil)  --script
prop:reader("outputs", nil) --outputs

function NodeScript:__init(case)
end

function NodeScript:on_load(conf)
    self.script = conf.script
    self.outputs = conf.outputs
    return true
end

function NodeScript:on_action()
    self:write_outputs(self.outputs)
    self:run_script(self.script)
    return true
end

return NodeScript