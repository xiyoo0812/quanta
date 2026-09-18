--node_base.lua
local tcopy         = table.copy
local sformat       = string.format
local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn

local thread_mgr    = quanta.get("thread_mgr")

local NodeBase = class()
local prop = property(NodeBase)
prop:reader("id", nil)          --id
prop:reader("case", nil)        --case
prop:reader("name", nil)        --name
prop:reader("error", nil)       --error
prop:reader("actor", nil)       --actor
prop:reader("after", nil)       --after
prop:reader("before", nil)      --before
prop:reader("open_id", nil)     --open_id
prop:reader("successed", nil)   --successed
prop:reader("running", false)   --running
prop:reader("result", true)     --result

function NodeBase:__init(case, id)
    self.id = id
    self.case = case
    self.actor = case.actor
    self.open_id = self.actor.open_id
end

function NodeBase:destroy()
end

function NodeBase:load(conf)
    self.next = conf.next
    self.after = conf.after
    self.before = conf.before
    self.name = sformat("%s:%s-%s", self.case.name, conf.name, self.id)
    return self:on_load(conf)
end

--写入输出
function NodeBase:write_output(name, output, res)
    local role = self.actor
    local outval = output.value
    if output.type == "attr" then
        if res[outval] then
            role[name] = res[outval]
        end
        return true
    end
    if output.type == "var" then
        if res[outval] then
            role.variables[name] = res[outval]
        end
        return true
    end
    if output.type == "lua" then
        role[name] = self:call_script(outval, res)
        return true
    end
    if outval ~= nil then
        role[name] = outval
    end
    return true
end

--读取输入
function NodeBase:read_input(input)
    local role = self.actor
    local intval = input.value
    if input.type == "var" then
        return role.variables[intval]
    end
    if input.type == "attr" then
        return role[intval]
    end
    if input.type == "number" then
        return tonumber(intval)
    end
    if input.type == "lua" then
        return self:call_script(intval)
    end
    return intval
end

--批量输入
function NodeBase:read_inputs(inputs)
    local values = {}
    for name, input in pairs(inputs or {}) do
        local value = self:read_input(input)
        if value == nil then
            log_warn("[NodeBase][read_inputs] robot:{} run node=> {} name:{} value {} failed: {}", self.open_id, self.name, name, input.value, value)
            return nil, sformat("collect inputs %s failed!", name)
        end
        values[name] = value
    end
    return values
end

--批量输出
function NodeBase:write_outputs(outputs, res)
    tcopy(res, self.actor.variables)
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
        log_warn("[NodeBase][exec_script] robot:{} run node=> {} load script {} failed: {}", self.open_id, self.name, expr, func)
        self:failed(func)
        return
    end
    local ok2, value = pcall(func, role, role.variables, res)
    if not ok2 then
        log_warn("[NodeBase][exec_script] robot:{} run node=> {} exec script {} failed: {}", self.open_id, self.name, expr, value)
        self:failed(value)
        return
    end
    return value
end

--沉睡ms
function NodeBase:sleep(ms)
    thread_mgr:sleep(ms)
end

function NodeBase:start()
    self.running = true
    self:run_script(self.before)
    self.actor:push_state(self, "running")
    log_info("[NodeBase][start] robot:{} run node=> {} begin!", self.open_id, self.name)
    local ok, res = pcall(self.on_start, self)
    if not ok then
        self:failed(res)
        return false
    end
    return true
end

function NodeBase:stop()
    self.successed = true
    local ok, res = pcall(self.on_stop, self)
    if not ok then
        self:failed(res)
        return
    end
    self.actor:push_state(self, "success")
    self:run_script(self.after)
    log_info("[NodeBase][stop] robot:{} run node=> {} success!", self.open_id, self.name)
    self:go_next()
end

--执行
function NodeBase:update()
    if not self.running then
        if not self:start() then
            return
        end
    end
    if self:on_update() then
        self:stop()
    end
end

function NodeBase:go_next()
    self.case:run_next(self.next)
end

function NodeBase:failed(error)
    self.error = error
    self.result = false
    self.successed = false
    log_err("[NodeBase][failed] robot:{} run node=> {} failed: {}", self.open_id, self.name, error)
    self.actor:push_state(self, "failed")
    self.case:failed()
end

function NodeBase:on_update()
    return self.result
end

function NodeBase:on_load(conf)
    return true
end

function NodeBase:on_start()
end

function NodeBase:on_stop()
end

return NodeBase
