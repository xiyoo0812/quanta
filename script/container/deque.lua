--deque.lua
--队列: 普通双端队列，元素可重复
--索引队列： 支持索引，元素不能重复
local qtweak    = qtable.weak
local log_warn  = logger.warn

local Deque = class()
local prop = property(Deque)
prop:reader("first", 1)
prop:reader("tail", 0)
prop:reader("index", nil)
prop:reader("indexs", nil)
prop:reader("datas", {})

function Deque:__init(index)
    if index then
        self.index = index
        self.indexs = qtweak({})
    end
end

function Deque:clear()
    self.indexs = qtweak({})
    self.datas = {}
    self.first = 1
    self.tail = 0
end

function Deque:size()
    return self.tail - self.first + 1
end

function Deque:empty()
    return self.tail + 1 == self.first
end

function Deque:head()
    return self:elem(1)
end

function Deque:elem(pos)
    local key = self.first - 1 + pos
    if key < self.first or key > self.tail then
        return
    end
    return self.datas[key]
end

function Deque:build_index(value)
    if self.index then
        local idxkey = value[self.index]
        if not idxkey then
            log_warn("[Deque][build_index] index is nil")
            return false
        end
        if self.indexs[idxkey] then
            return false
        end
        self.indexs[idxkey] = value
    end
    return true
end

function Deque:remove_index(value)
    if self.index then
        local idxkey = value[self.index]
        self.indexs[idxkey] = nil
    end
end

function Deque:find(idx)
    if self.indexs then
        return self.indexs[idx]
    end
end

function Deque:push_front(value)
    if not self:build_index(value) then
        return false
    end
    self.first = self.first - 1
    self.datas[self.first] = value
    return true
end

function Deque:pop_front()
    local first, tail = self.first, self.tail
    if first > tail then
        self.first = 1
        self.tail = 0
        return
    end
    local value = self.datas[first]
    self.datas[first] = nil
    self.first = first + 1
    self:remove_index(value)
    return value
end

function Deque:push_back(value)
    if not self:build_index(value) then
        return false
    end
    self.tail = self.tail + 1
    self.datas[self.tail] = value
    return true
end

function Deque:pop_back()
    local first, tail = self.first, self.tail
    if first > tail then
        self.first = 1
        self.tail = 0
        return
    end
    local value = self.datas[tail]
    self.datas[tail] = nil
    self.tail = tail - 1
    self:remove_index(value)
    return value
end

function Deque:insert(pos, value)
    local first, tail = self.first, self.tail
    if pos <= 0 or first + pos > tail + 2 then
        log_warn("[Deque][insert]bad pos to insert")
        return false
    end
    if not self:build_index(value) then
        return false
    end
    local realp = first + pos - 1
    if realp <= (first + tail) / 2 then
        for i = first, realp do
            self.datas[i- 1] = self.datas[i]
        end
        self.datas[realp- 1] = value
        self.first = first - 1
    else
        for i = tail, realp, -1 do
            self.datas[i+ 1] = self.datas[i]
        end
        self.datas[realp] = value
        self.tail = tail + 1
    end
    return true
end

function Deque:remove(pos)
    local first, tail = self.first, self.tail
    if pos <= 0 then
        log_warn("[Deque][remove]bad pos to remove")
        return
    end
    if first + pos - 1 > tail then
        return
    end
    local realp = first + pos - 1
    local value = self.datas[realp]
    if self:size() == 1 then
        self:clear()
        return value
    end
    if realp <= (first + tail) / 2 then
        for i = realp, first, -1 do
            self.datas[i] = self.datas[i - 1]
        end
        self.first = first + 1
    else
        for i = realp, tail do
            self.datas[i] = self.datas[i + 1]
        end
        self.tail = tail - 1
    end
    self:remove_index(value)
    return value
end

--按照索引删除
function Deque:remove_by_index(index)
    for pos, elem in pairs(self.datas) do
        if elem[self.index] == index then
            self:remove(pos - self.first + 1)
            break
        end
    end
end

--迭代器
function Deque:iter()
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

return Deque
