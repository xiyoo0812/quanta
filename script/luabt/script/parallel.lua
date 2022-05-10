--parallel.lua
local ipairs        = ipairs
local FAIL          = luabt.FAIL
local SUCCESS       = luabt.SUCCESS
local RUNNING       = luabt.RUNNING
local FAIL_ONE      = luabt.FAIL_ONE
local FAIL_ALL      = luabt.FAIL_ALL
local SUCCESS_ALL   = luabt.SUCCESS_ALL
local SUCCESS_ONE   = luabt.SUCCESS_ONE

local node_execute  = luabt.node_execute

local ParallelNode = class()
--fail_policy == luabt.FAIL_ALL or Const.FAIL_ONE
--success_policy == luabt.SUCCESS_ALL or Const.SUCCESS_ONE
function ParallelNode:__init(fail_policy, success_policy, ...)
    self.name = "parallel"
    self.fail_policy = fail_policy
    self.success_policy = success_policy
    self.children = {...}
end

-- luacheck: ignore 561
function ParallelNode:run(btree, data)
    local saw_success = false
    local saw_fail = false
    local saw_running = false
    local saw_all_fail = true
    local saw_all_success = true

    for _, node in ipairs(self.children) do
        local status = node_execute(node, btree, data.__level + 1)
        if status == FAIL then
            saw_fail = true
            saw_all_success = false
        elseif status == SUCCESS then
            saw_success = true
            saw_all_fail = false
        else
            saw_running = true
            saw_all_fail = false
            saw_all_success = false
        end
    end

    local result = saw_running and RUNNING or FAIL

    if self.fail_policy == FAIL_ALL and saw_all_fail or
       self.fail_policy == FAIL_ONE and saw_fail then
        result = FAIL
    elseif self.success_policy == SUCCESS_ALL and saw_all_success or
       self.success_policy == SUCCESS_ONE and saw_success then
       result = SUCCESS
    end

    return result
end

function ParallelNode:close(btree)
    for _, node in ipairs(self.children) do
        local node_data = btree[node]
        if node_data and node_data.is_open then
            node_data.is_open = false
            if node.close then
                node:close(btree, node_data)
            end
        end
    end
end

return ParallelNode
