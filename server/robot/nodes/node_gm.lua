--node_gm.lua

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeGM = class(NodeBase)
local prop = property(NodeGM)
prop:reader("cmd", nil)     --cmd
prop:reader("time", nil)    --time

function NodeGM:__init(case)
end

function NodeGM:on_load(conf)
    self.cmd = conf.cmd
    self.time = conf.time
    return true
end

function NodeGM:on_action()
    self.actor:send_gm(self.cmd)
    if self.time then
        self:sleep(self.time)
    end
    return true
end

return NodeGM
