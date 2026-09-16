--node_ntf.lua
local log_warn      = logger.warn
local log_debug     = logger.debug
local sformat       = string.format

local event_mgr     = quanta.get("event_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

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
    self.name = sformat("%s-%s:%s", conf.name, self.id, conf.cmd_id)
    return true
end

function NodeNtf:on_start()
    local cmd_name = self.cmd_id
    if cmd_name then
        if type(cmd_name) == "number" then
            cmd_name = protobuf_mgr:msg_name(cmd_name)
        end
        NodeNtf[cmd_name] = function(obj, session, message, body)
            obj:write_outputs(obj.outputs, body)
        end
        event_mgr:add_pb_listener(self, cmd_name, cmd_name)
    end
end

function NodeNtf:on_update()
    if self.cmd_id and self.cond then
        local role = self.actor
        local ok, res = role:wait(self.cmd_id, CALL_TIMEOUT)
        if not ok then
            self:failed(res)
            return false
        end
        local cond = self:call_script(self.cond, res)
        if cond == nil then
            log_warn("[NodeNtf][on_update] robot:{} cond {} id null", role.open_id, self.cond)
            self:failed("cond error")
            return false
        end
        if not cond then
            return false
        end
        log_debug("[NodeNtf][on_update] robot:{} wait {} success", role.open_id, self.cmd_id)
    end
    return true
end

return NodeNtf
