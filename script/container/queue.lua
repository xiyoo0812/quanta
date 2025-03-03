--queue.lua
--单向队列

local Queue = class()
local prop = property(Queue)
prop:reader("max", nil)
prop:reader("first", 1)
prop:reader("tail", 0)
prop:reader("datas", {})

function Queue:__init(max)
    self.max = max
end

function Queue:clear()
    self.datas = {}
    self.first = 1
    self.tail = 0
end

function Queue:size()
    return self.tail - self.first + 1
end

function Queue:empty()
    return self.tail + 1 == self.first
end

function Queue:head()
    return self:elem(1)
end

function Queue:elem(pos)
    local index = self.first - 1 + pos
    if index > self.tail then
        return
    end
    return self.datas[index]
end

function Queue:push(value)
    self.tail = self.tail + 1
    self.datas[self.tail] = value
    if self.max and self:size() > self.max then
        return self:pop()
    end
end

function Queue:pop()
    local first, tail = self.first, self.tail
    if first > tail then
        self.first = 1
        self.tail = 0
        return
    end
    local value = self.datas[first]
    self.datas[first] = nil
    self.first = first + 1
    return value
end

--迭代器
function Queue:iter()
    local datas = self.datas
    local index, tail = self.first - 1, self.tail
    local function _iter()
        index = index + 1
        if index <= tail then
            return index - self.first + 1, datas[index]
        end
    end
    return _iter
end

return Queue