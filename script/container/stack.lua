--stack.lua
local tcopy = qtable.copy

local Stack = class()
local prop = property(Stack)
prop:reader("datas", {})

function Stack:__init()
end

function Stack:clear()
    self.datas = {}
end

function Stack:size()
    return #self.datas
end

function Stack:empty()
    return #self.datas == 0
end

function Stack:top()
    local size = #self.datas
    if size > 0 then
        return self.datas[size]
    end
end

function Stack:push(elem)
    self.datas[#self.datas + 1] = elem
end

function Stack:pop()
    local size = #self.datas
    local elem = self.datas[size]
    self.datas[size] = nil
    return elem
end

function Stack:clone()
    local co = Stack()
    tcopy(self.datas, co.datas)
    return co
end

return Stack
