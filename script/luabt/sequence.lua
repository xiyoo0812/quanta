--sequence.lua
local ipairs    = ipairs

local FAIL      = luabt.FAIL
local WAITING   = luabt.WAITING

local Node      = luabt.Node

local SequenceNode = class(Node)
function SequenceNode:__init(...)
    self.name = "sequence"
    self.childs = {...}
    self.index = 0
end

function SequenceNode:run(tree)
    local status = tree:get_status()
    if status == FAIL then
        return FAIL
    end
    local index = self.index + 1
    if index > #self.childs then
        return status
    end
    self.childs[index]:open(tree)
    self.index = index
    return WAITING
end

function SequenceNode:on_close(tree)
    self.index = 0
    for _, child in ipairs(self.childs) do
        child:close(tree)
    end
end

return SequenceNode
