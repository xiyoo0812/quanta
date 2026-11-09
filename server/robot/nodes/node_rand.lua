--node_rand.lua
local log_warn  = logger.warn

local Random    = import("basic/random.lua")
local NodeBase  = import("robot/nodes/node_base.lua")

local NodeRand = class(NodeBase)
local prop = property(NodeRand)
prop:reader("rand", nil)        --rand

function NodeRand:__init(case)
end

function NodeRand:on_load(conf)
    self.rand = Random()
    for index, weight in pairs(conf.targets or {}) do
        self.rand:add_wheel(index, weight)
    end
    return true
end

function NodeRand:on_start()
    local role = self.actor
    local index = self.rand:rand_wheel()
    if not index then
        log_warn("[NodeRand][on_start] robot:{} rand {} targets is empty", role.open_id, self.name)
        self:failed("rand targets is empty")
        return false
    end
    self.next = index
    return true
end

return NodeRand
