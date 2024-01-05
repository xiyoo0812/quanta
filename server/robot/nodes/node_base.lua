--node_base.lua
local tcopy         = qtable.copy
local sformat       = string.format
local log_warn      = logger.warn

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local NodeBase = class()
local prop = property(NodeBase)
prop:reader("case", nil)        --case
prop:reader("next", nil)        --next
prop:reader("actor", nil)       --actor

function NodeBase:__init(case)
    self.case = case
    self.actor = case.actor
end

function NodeBase:watch(cmd_id)
    event_mgr:notify_listener("on_watch_message", cmd_id)
end

function NodeBase:load(conf)
    self.next = conf.next
    return self:on_load(conf)
end

--写入输出
function NodeBase:write_output(name, output, res)
    local role = self.actor
    if output.type == "attr" then
        role[name] = res[output.value]
        return true
    end
    if output.type == "var" then
        self.case.variables[name] = res[output.value]
        return true
    end
    if output.type == "lua" then
        self:run_script(output.value, res)
        return true
    end
    role[name] = output.value
    return true
end

--读取输入
function NodeBase:read_input(input)
    if input.type == "var" then
        return self.case.variables[input.value]
    end
    local role = self.actor
    if input.type == "attr" then
        return role[input.value]
    end
    if input.type == "lua" then
        return self:call_script(input.value)
    end
    return input.value
end

--批量输入
function NodeBase:read_inputs(inputs)
    local values = {}
    for name, input in pairs(inputs or {}) do
        local value = self:read_input(input)
        if not value then
            log_warn("[NodeBase][read_inputs] name:{} avalue {} failed: {}", name, input.value, value)
            return
        end
        values[name] = value
    end
    return values
end

--批量输出
function NodeBase:write_outputs(outputs, res)
    tcopy(res, self.case.variables)
    for name, output in pairs(outputs or {}) do
        self:write_output(name, output, res)
    end
end

--调用脚本
function NodeBase:run_script(script, res)
    if script then
        local expr = sformat("return function(robot, vars, res) %s end", script)
        return self:exec_script(expr, res or {})
    end
end

--执行脚本，有返回值
function NodeBase:call_script(script, res)
    if script then
        local expr = sformat("return function(robot, vars, res) return %s end", script)
        return self:exec_script(expr, res or {})
    end
end

function NodeBase:exec_script(expr, res)
    local role = self.actor
    local ok, func = pcall(load(expr))
    if not ok then
        log_warn("[NodeBase][run_script] robot:{} load script {} failed: {}", role.open_id, expr, func)
        return
    end
    local ok2, value = pcall(func, role, self.case.variables, res)
    if not ok2 then
        log_warn("[NodeBase][run_script] robot:{} exec script {} failed: {}", role.open_id, expr, value)
        return
    end
    return value
end

--沉睡ms
function NodeBase:sleep(ms)
    thread_mgr:sleep(ms)
end

--执行
function NodeBase:action()
    if not self:on_action() then
        return
    end
    self:go_next()
end

function NodeBase:go_next()
    self.case:run_next(self.next)
end

function NodeBase:failed()
    self.case:failed()
end

function NodeBase:on_action()
    return true
end

function NodeBase:on_load(conf)
    return true
end

return NodeBase
