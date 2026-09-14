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

function NodeSock:on_start()
    local role = self.actor
    local ip = self:read_input(self.ip)
    local port = self:read_input(self.port)
    if not ip or not port then
        log_warn("[NodeSock][on_start] robot:{} ip={}, port={}", role.open_id, ip, port)
        self:failed("ip or port error")
        self.result = false
        return
    end
    local ok, res = role:connect(ip, port, true)
    if not ok then
        log_warn("[NodeSock][on_start] robot:{} connect {}:{} failed: {}", role.open_id, ip, port, res)
        self:failed("ip or port error")
        self.result = false
        return
    end
    log_debug("[NodeSock][on_start] robot:{} connect {}:{} success", role.open_id, ip, port)
end

return NodeSock
