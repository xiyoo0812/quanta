--node_case.lua

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeCase = class(NodeBase)
local prop = property(NodeCase)
prop:reader("child", nil)       --child

function NodeCase:__init(case)
end

function NodeCase:on_load(conf)
    local ccase = self.actor:create_case(conf.case)
    if not ccase then
        return false
    end
    ccase:set_parent(self.case)
    self.child = ccase
    return true
end

function NodeCase:on_action()
    if self.child then
        self.actor:run_case(self.child)
    end
    return true
end

return NodeCase
