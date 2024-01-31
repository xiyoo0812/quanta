--node_ntf.lua
local log_warn      = logger.warn
local log_debug     = logger.debug

local NodeBase      = import("robot/nodes/node_base.lua")

local CALL_TIMEOUT  = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local NodeNtf = class(NodeBase)
local prop = property(NodeNtf)
prop:reader("cond", nil)    --cond
prop:reader("cmd_id", nil)  --cmd_id
prop:reader("outputs", nil) --outputs

function NodeNtf:__init(case)
end

function NodeNtf:on_load(conf)
    self.cond = conf.cond
    self.cmd_id = conf.cmd_id
    self.outputs = conf.outputs
    self:watch(self.cmd_id)
    return true
end

function NodeNtf:on_action()
    if self.cmd_id then
        local role = self.actor
        local ok, res = role:wait(self.cmd_id, CALL_TIMEOUT)
        if not ok then
            self:failed(res)
            return false
        end
        if self.cond then
            local cond = self:call_script(self.cond, res)
            if cond == nil then
                log_warn("[NodeNtf][on_action] robot:{} cond {} id null", role.open_id, self.cond)
                self:failed("cond error")
                return false
            end
            if not cond then
                return false
            end
            log_debug("[NodeNtf][on_action] robot:{} wait {} success", role.open_id, self.cmd_id)
        end
        self:write_outputs(self.outputs, res)
    end
    return true
end

return NodeNtf
