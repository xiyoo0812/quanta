--repeat.lua

local RUNNING   = luabt.RUNNING

local Node      = luabt.Node

local RepeatNode = class(Node)
function RepeatNode:__init(count, node)
    self.name = "repeat"
    self.child = node
    self.count = count
    self.index = 0
end

function RepeatNode:run(tree)
    self.index = self.index + 1
    if self.index < self.count then
        self.child:open(tree)
        return RUNNING
    end
    return tree.status
end

function RepeatNode:on_close()
    self.index = 0
end

return RepeatNode
