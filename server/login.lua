--quanta
import("kernel.lua")

local env_addr  = environ.addr
quanta.startup(function()
    --创建客户端网络管理
    local NetServer = import("network/net_server.lua")
    local client_mgr = NetServer("login")
    client_mgr:listen(env_addr("QUANTA_LOGIN_ADDR"))
    quanta.client_mgr = client_mgr

    --加载登陆管理
    import("store/store_mgr.lua")
    import("login/login_dao.lua")
    import("login/login_mgr.lua")
    import("login/login_servlet.lua")
    -- 协议过滤器
    import("business/admin/shield.lua")
end)
