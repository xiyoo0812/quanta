--node_req.lua
local log_warn  = logger.warn
local log_debug = logger.debug
local sformat   = string.format

local event_mgr = quanta.get("event_mgr")

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeReq = class(NodeBase)
local prop = property(NodeReq)
prop:reader("cmd_id", nil)  --cmd_id
prop:reader("inputs", nil)  --inputs
prop:reader("outputs", nil) --outputs

function NodeReq:__init(case)
end

function NodeReq:on_load(conf)
    self.cmd_id = conf.cmd_id
    self.inputs = conf.inputs
    self.outputs = conf.outputs
    self.name = sformat("%s-%s:%s", conf.name, self.id, conf.cmd_id)
    return true
end

function NodeReq:on_start()
    if self.cmd_id then
        local role = self.actor
        local values, err = self:read_inputs(self.inputs)
        if not values then
            log_warn("[NodeReq][on_start] robot:{}  call {} collect inputs {} failed!", role.open_id, self.cmd_id, self.inputs)
            self:failed(err)
            return
        end
        log_debug("[NodeReq][on_start] robot:{} call {}=>{}", role.open_id, self.cmd_id, values)
        local ok, res = role:call(self.cmd_id, values)
        if role:check_callback(ok, res) then
            log_warn("[NodeReq][on_start] robot:{} call {} failed: ok={}, res={}", role.open_id, self.cmd_id, ok, res)
            event_mgr:notify_trigger("on_error_message", self.cmd_id, role.open_id, res)
            self:failed(res)
            return
        end
        log_debug("[NodeReq][on_start] robot:{} call {}=>{} success", role.open_id, self.cmd_id, res)
        self:write_outputs(self.outputs, res)
    end
end

return NodeReq
