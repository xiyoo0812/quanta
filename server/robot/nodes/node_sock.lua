--node_sock.lua
local log_warn  = logger.warn
local log_debug = logger.debug
local qsaddr    = qstring.addr

local NodeBase  = import("robot/nodes/node_base.lua")

local NodeSock = class(NodeBase)
local prop = property(NodeSock)
prop:reader("addr", nil)    --addr

function NodeSock:__init(case)
end

function NodeSock:on_load(conf)
    self.addr = conf.addr
    return true
end

function NodeSock:on_start()
    local role = self.actor
    local addr = self:read_input(self.addr)
    local ip, port = qsaddr(addr)
    if not ip or not port then
        log_warn("[NodeSock][on_start] robot:{} run node:{}'s ip={}, port={}", role.open_id, self.name, ip, port)
        self:failed("addr {} config error", addr)
        return
    end
    local ok, res = role:connect(ip, port, true)
    if not ok then
        log_warn("[NodeSock][on_start] robot:{} run node:{}'s connect {}:{} failed: {}", role.open_id, self.name, ip, port, res)
        self:failed("addr {} connect error", addr, res)
        return
    end
    log_debug("[NodeSock][on_start] robot:{} run node:{}'s connect {}:{} success", role.open_id, self.name, ip, port)
end

return NodeSock
