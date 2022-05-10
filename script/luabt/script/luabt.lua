--luabt.lua
local pairs     = pairs
local mrandom   = math.random

luabt = {
    -- Node Status
    SUCCESS     = 1,
    FAIL        = 2,
    RUNNING     = 3,
    -- Parallel Policy
    SUCCESS_ONE = 1,    -- success when one child success
    SUCCESS_ALL = 2,    -- success when all children success
    FAIL_ONE    = 3,    -- fail when one child fail
    FAIL_ALL    = 4,    -- fail when all children fail
}

local SUCCESS   = luabt.SUCCESS
local RUNNING   = luabt.RUNNING

function luabt.create_node(btcls_node, ...)
    return btcls_node(...)
end

function luabt.node_execute(node, btree, level)
    local node_data = btree[node] or {}
    node_data.__level = level
    btree[node] = node_data

    btree:node_trace(btree, level, node)
    -- open callback
    if not node_data.is_open then
        if node.open then
            local ret = node:open(btree, node_data)
            if ret then
                btree:node_status(node, ret)
                node_data.is_open = false
                return ret
            end
        end
        node_data.is_open = true
    end

    -- run callback, get status
    local status = node:run(btree, node_data)
    btree:node_status(btree, node, status)

    -- close callback
    if status == RUNNING then
        btree.open_nodes[node] = true
        return status
    else
        node_data.is_open = false
        if node.close then
            node:close(btree, node_data)
        end
        return status
    end
end

-- 根据权重决定子节点索引的顺序
function luabt.node_reorder(indexes, weight, total)
    for i = 1, #indexes do
        local rnd = mrandom(total)
        local acc = 0
        for j = i, #indexes do
            local w = weight[indexes[j]]
            acc = acc + w
            if rnd <= acc then
                indexes[i], indexes[j] = indexes[j], indexes[i]
                total = total - w
                break
            end
        end
    end
end

local LuaBT = class()
local prop = property(LuaBT)
prop:reader("frame", 0)
prop:reader("root", nil)
prop:reader("robot", nil)
prop:reader("nodes", {})
prop:reader("stack", {})
prop:reader("last_open", {})    --上一次 tick 运行中的节点
prop:reader("open_nodes", {})
prop:accessor("log_status", false)

function LuaBT:__init(robot, root)
    self.robot = robot
    self.root = root
end

function LuaBT:tick()
    self:clear()
    local status = luabt.node_execute(self.root, self, 0)
    -- close open nodes if necessary
    local openNodes = self.open_nodes
    local lastOpen = self.last_open
    for node in pairs(lastOpen) do
        local node_data = self[node]
        if not openNodes[node] and node_data.is_open then
            node_data.is_open = false
            if node.close then
                node:close(self, node_data)
            end
        end
        lastOpen[node] = nil
    end
    self.last_open = openNodes
    self.open_nodes = lastOpen  -- empty table
    self.frame = self.frame + 1
    return status == SUCCESS
end

function LuaBT:clear()
    if self.log_status then
        self.stack = {}
        self.nodes = {}
    end
end

function LuaBT:trace()
    for _, node in pairs(self.stack) do
        print("lua bt stack level:%d, node:%s, status:%s", node.level, node.node.name, node.status)
    end
end

function LuaBT:node_trace(bt, level, node)
    if not self.log_status then
        return
    end
    local node_info = {
        node = node,
        level = level,
    }
    self.stack[#self.stack + 1] = node_info
    self.nodes[node] = node_info
end

local function st2str(status)
    if status == SUCCESS then
        return "SUCCESS"
    elseif status == RUNNING then
        return "RUNNING"
    else
        return "FAIL"
    end
end

function LuaBT:node_status(bt, node, status)
    local node_info = self.nodes[node]
    if node_info then
        node_info.status = st2str(status)
    end
end

return LuaBT
