--discover_mgr.lua
local RpcServer     = import("network/rpc_server.lua")
local HttpServer    = import("network/http_server.lua")

local env_get       = environ.get
local env_addr      = environ.addr
local log_warn      = logger.warn
local log_info      = logger.info
local log_debug     = logger.debug
local signal_quit   = signal.quit

local event_mgr     = quanta.get("event_mgr")
local timer_mgr     = quanta.get("timer_mgr")

local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")

local DiscoverMgr = singleton()
local prop = property(DiscoverMgr)
prop:reader("host", nil)
prop:reader("port", 0)
prop:reader("rpc_server", nil)
prop:reader("http_server", nil)
prop:reader("service_list", {})
prop:reader("watcher_list", {})

function DiscoverMgr:__init()
    --创建rpc服务器
    local ip, port = env_addr("QUANTA_DISCOVER_HOST")
    self.rpc_server = RpcServer(self, ip, port)
    --创建HTTP服务器
    local server = HttpServer(env_get("QUANTA_DISCOVER_HTTP"))
    server:register_post("/command", "on_server_command", self)
    server:register_post("/shutdown", "on_server_shutdown", self)
    --初始化变量
    self.host = ip
    self.http_server = server
    self.port = server:get_port()
    --加载服务发现
    self:load_discover()
end

function DiscoverMgr:load_discover()
    --监听事件
    event_mgr:add_listener(self, "rpc_watch_service")
    --梳理服务
    for _, service_name in pairs(service.services()) do
        self.watcher_list[service_name] = {}
        self.service_list[service_name] = {}
    end
end

function DiscoverMgr:on_client_accept(client)
    local routers = self.service_list["router"]
    if next(routers) then
        self.rpc_server:send(client, "rpc_service_ready", "router", routers)
    end
end

-- 心跳
function DiscoverMgr:on_client_beat(client)
end

function DiscoverMgr:on_client_register(client, node)
    local token = client.token
    local serv_name = node.service_name
    local services = self.service_list[serv_name]
    log_debug("[DiscoverMgr][on_service_register] node:{}, token: {}", node, token)
    if not services then
        return
    end
    services[token] = node
    if serv_name == "router" then
        self.rpc_server:unservicecast(node.service, "rpc_service_ready", serv_name, { node })
    else
        local watchers = self.watcher_list[serv_name] or {}
        self.rpc_server:groupecast(watchers, "rpc_service_ready", serv_name, { node })
    end
end

-- 会话关闭回调
function DiscoverMgr:on_client_error(client, token, err)
    local serv_name = client.service_name
    local services = self.service_list[serv_name]
    log_info("[DiscoverMgr][on_client_error] node:{}, token:{}", client.name, token)
    if not services or not services[token] then
        return
    end
    services[token] = nil
    --清理观察的服务
    for _, watchers in pairs(self.watcher_list) do
        watchers[token] = nil
    end
    if serv_name == "router" then
        self.rpc_server:unservicecast(client.service, "rpc_service_close", client.id, serv_name)
    else
        local watchers = self.watcher_list[serv_name] or {}
        self.rpc_server:groupecast(watchers, "rpc_service_close", client.id, serv_name)
    end
end

function DiscoverMgr:rpc_watch_service(client, serv_name)
    log_info("[DiscoverMgr][rpc_watch_service] node:{}, watch:{}", client.name, serv_name)
    local watchers = self.watcher_list[serv_name]
    if not watchers then
        return
    end
    watchers[client.token] = true
    --发送当前的所有节点
    local services = self.service_list[serv_name]
    if next(services) then
        self.rpc_server:send(client, "rpc_service_ready", serv_name, services)
    end
end

--transfer
function DiscoverMgr:transfer(token, rpc, ...)
    local client = self.rpc_server:get_client(token)
    if not client then
        return {code = 1, msg = "node not connect!"}
    end
    local ok, res = self.rpc_server:call(client, "rpc_remote_message", rpc, ...)
    if not ok then
        return {code = 1, msg = "call moniotor node failed!"}
    end
    return res
end

-- command处理
function DiscoverMgr:on_server_command(url, body)
    log_debug("[DiscoverMgr][on_server_command]: {}", body)
    --执行函数
    local function handler_cmd(jbody)
        if jbody.token then
            return self:transfer(jbody.token, jbody.rpc, jbody.data)
        end
        self.rpc_server:servicecast(jbody.service_id, jbody.rpc, jbody.data)
        return {code = 0, msg = "broadcast all nodes server!"}
    end
    --开始执行
    local ok, res = pcall(handler_cmd, body)
    if not ok then
        log_warn("[DiscoverMgr][on_server_command] pcall: {}", res)
        return { code = 1, msg = res }
    end
    return res
end

-- 退出
function DiscoverMgr:on_server_shutdown(url, body)
    log_debug("[DiscoverMgr][on_server_shutdown] discover quit")
    --发出退出进程
    self.rpc_server:broadcast_all("rpc_server_shutdown", body.data)
    -- 关闭会话连接
    timer_mgr:loop(SECOND_10_MS, function()
        log_warn("[DiscoverMgr][on_server_shutdown]->service:{}", quanta.name)
        signal_quit()
    end)
    return "success"
end

quanta.discover_mgr = DiscoverMgr()

return DiscoverMgr
