--node_gm.lua

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeGM = class(NodeBase)
local prop = property(NodeGM)
prop:reader("cmds", nil)    --cmds
prop:reader("time", nil)    --time

function NodeGM:__init(case)
end

function NodeGM:on_load(conf)
    self.cmds = conf.cmds
    self.time = conf.time
    return true
end

function NodeGM:on_action()
    for _, cmd in pairs(self.cmds or {}) do
        self.actor:send_gm(cmd)
    end
    if self.time then
        self:sleep(self.time)
    end
    return true
end

return NodeGM
