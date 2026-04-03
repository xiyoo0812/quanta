-- gateway_mgr.lua

local log_debug         = logger.debug

local discover          = quanta.load("discover")

local GatewayMgr = singleton()
local prop = property(GatewayMgr)
prop:reader("gateways", {})
prop:reader("candidates", {})

function GatewayMgr:__init()
    --router接口
    discover:watch_service(self, "gateway")
end

--服务关闭
function GatewayMgr:on_service_close(id, name)
    log_debug("[GatewayMgr][on_service_close] node: {}-{}", name, id)
    local gateway = self.gateways[id]
    if gateway then
        gateway:close()
    end
end

--服务上线
function GatewayMgr:on_service_ready(id, name, info)
    log_debug("[GatewayMgr][on_service_ready] node: {}-{}, info: {}", name, id, info)
    self:add_gateway(info.id, info.host, info.port)
end

--添加router
function GatewayMgr:add_gateway(gateway_id, host, port)
    local gateway = self.gateways[gateway_id]
    if gateway then
        gateway:relocation(host, port)
        return
    end
    local GateSession = import("network/gate_session.lua")
    self.gateways[gateway_id] = GateSession(host, port, gateway_id)
end

function GatewayMgr:get_gateway(gateway_id)
    return self.gateways[gateway_id]
end

quanta.gateway_mgr = GatewayMgr()

return GatewayMgr
