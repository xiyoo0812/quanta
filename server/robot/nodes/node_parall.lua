--node_parall.lua
local log_warn  = logger.warn
local makechan  = quanta.make_channel

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeParall = class(NodeBase)
local prop = property(NodeParall)
prop:reader("childs", {})   --childs
prop:reader("channel", nil) --channel

function NodeParall:__init(case)
end

function NodeParall:on_load(conf)
    local channel = makechan("node_parall")
    for _, child in piars(conf.childs or {}) do
        channel:push(function()
            
        end)
    end
    self.channel = channel
    return true
end

function NodeParall:on_action()
    if self.channel then
        local ok, code =  self.channel:execute()
        if not ok then
            log_warn("[NodeParall][on_action] robot:{} code {}", self.actor.open_id, code)
            self:failed("cond error")
            return false
        end
    end
    return true
end

return NodeParall
