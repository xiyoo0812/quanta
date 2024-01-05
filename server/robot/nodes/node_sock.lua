--node_sock.lua
local log_warn  = logger.warn
local log_debug = logger.debug

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeSock = class(NodeBase)
local prop = property(NodeSock)
prop:reader("ip", nil)      --ip
prop:reader("port", nil)    --port

function NodeSock:__init(case)
end

function NodeSock:on_load(conf)
    self.ip = conf.ip
    self.port = conf.port
    return true
end

function NodeSock:on_action()
    local role = self.actor
    local ip = self:read_input(self.ip)
    local port = self:read_input(self.port)
    if not ip or not port then
        log_warn("[NodeSock][on_action] robot:{} ip={}, port={}", role.open_id, ip, port)
        self:failed("ip or port error")
        return false
    end
    local ok, res = role:connect(ip, port, true)
    if not ok then
        self:failed("ip or port error")
        log_warn("[NodeSock][on_action] robot:{} connect {}:{} failed: {}", role.open_id, ip, port, res)
        return false
    end
    log_debug("[NodeSock][on_action] robot:{} connect {}:{} success", role.open_id, ip, port)
    return true
end

return NodeSock
