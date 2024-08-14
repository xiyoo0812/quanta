--quanta
import("kernel.lua")

local env_addr  = environ.addr

quanta.startup(function()
    --创建客户端网络管理
    local NetServer = import("network/net_server.lua")
    local ip, port = env_addr("QUANTA_GATEWAY_ADDR")
    local client_mgr = NetServer("gateway")
    client_mgr:listen(ip, port, true)
    quanta.client_mgr = client_mgr

    --初始化gateway
    import("agent/online_agent.lua")
    import("gateway/group_mgr.lua")
    import("gateway/gateway.lua")
    -- 协议过滤器
    import("business/admin/shield.lua")
end)
