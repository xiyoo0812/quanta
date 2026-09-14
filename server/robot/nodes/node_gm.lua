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

function NodeGM:on_start()
    for _, cmd in pairs(self.cmds or {}) do
        self.actor:send_gm(cmd)
    end
    if self.time and self.time > 0 then
        self:sleep(self.time)
    end
end

return NodeGM
