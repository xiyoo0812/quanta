--queue_fifo.lua

local QueueFIFO = class()
local prop = property(QueueFIFO)
prop:reader("head", 1)
prop:reader("tail", 0)
prop:reader("datas", {})

function QueueFIFO:__init()
end

function QueueFIFO:clear()
    self.datas = {}
    self.head = 1
    self.tail = 0
end

function QueueFIFO:size()
    return self.tail - self.head + 1
end

function QueueFIFO:empty()
    return self.tail + 1 == self.head
end

function QueueFIFO:peek(pos)
    local index = self.head - 1 + pos
    if index > self.tail then
        return false
    end
    return true, self.datas[index]
end

function QueueFIFO:push(value)
    self.tail = self.tail + 1
    self.datas[self.tail] = value
end

function QueueFIFO:pop()
    local head, tail = self.head, self.tail
    if head > tail then
        return
    end
    local value = self.datas[head]
    self.datas[head] = nil
    self.head = head + 1
    return value
end

--迭代器
function QueueFIFO:iter()
    local datas = self.datas
    local index, tail = self.head - 1, self.tail
    local function _iter()
        index = index + 1
        if index <= tail then
            return index - self.head + 1, datas[index]
        end
    end
    return _iter
end

return QueueFIFO