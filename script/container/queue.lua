--queue.lua
local log_err = logger.err

local Queue = class()
local prop = property(Queue)
prop:reader("head", 1)
prop:reader("tail", 0)
prop:reader("datas", {})

function Queue:__init()
end

function Queue:clear()
    self.datas = {}
    self.head = 1
    self.tail = 0
end

function Queue:size()
    return self.tail - self.head + 1
end

function Queue:empty()
    return self.tail + 1 == self.head
end

function Queue:peek(pos)
    local index = self.head - 1 + pos
    if index > self.tail then
        return false
    end
    return true, self.datas[index]
end

function Queue:lpush(value)
    self.head = self.head - 1
    self.datas[self.head] = value
end

function Queue:lpop()
    local head, tail = self.head, self.tail
    if head > tail then
        return
    end
    local value = self.datas[head]
    self.datas[head] = nil
    self.head = head + 1
    return value
end

function Queue:rpush(value)
    self.tail = self.tail + 1
    self.datas[self.tail] = value
end

function Queue:rpop()
    local head, tail = self.head, self.tail
    if head > tail then
        return
    end
    local value = self.datas[tail]
    self.datas[tail] = nil
    self.tail = tail - 1
    return value
end

function Queue:insert(pos, value)
    local head, tail = self.head, self.tail
    if pos <= 0 or head + pos > tail + 2 then
        log_err("[Queue][insert]bad index to insert")
        return false
    end
    local realp = head + pos - 1
    if realp <= (head + tail) / 2 then
        for i = head, realp do
            self.data[i- 1] = self.data[i]
        end
        self.data[realp- 1] = value
        self.head = head - 1
    else
        for i = tail, realp, -1 do
            self.data[i+ 1] = self.data[i]
        end
        self.data[realp] = value
        self.tail = tail + 1
    end
    return true
end

function Queue:remove(pos)
    local head, tail = self.head, self.tail
    if pos <= 0 then
        log_err("[Queue][insert]bad index to remove")
        return
    end
    if head + pos - 1 > tail then
        return
    end
    local realp = head + pos - 1
    local value = self.data[realp]
    if self:size() == 1 then
        self:clear()
        return value
    end
    if realp <= (head + tail) / 2 then
        for i = realp, head, -1 do
            self.data[i] = self.data[i - 1]
        end
        self.head = head + 1
    else
        for i = realp, tail do
            self.data[i] = self.data[i + 1]
        end
        self.tail = tail - 1
    end
    return value
end

--迭代器
function Queue:iter()
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

return Queue
