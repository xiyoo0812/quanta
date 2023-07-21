--monitor_mgr.lua
import("driver/nacos.lua")
local ljson         = require("lcjson")
local RpcServer     = import("network/rpc_server.lua")
local HttpServer    = import("network/http_server.lua")

local env_get       = environ.get
local env_addr      = environ.addr
local log_warn      = logger.warn
local log_info      = logger.info
local log_debug     = logger.debug
local jdecode       = ljson.decode
local signal_quit   = signal.quit

local timer_mgr     = quanta.get("timer_mgr")
local update_mgr    = quanta.get("update_mgr")

local DISCOVERY     = environ.get("QUANTA_DISCOVERY", "redis")

local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")

local MonitorMgr = singleton()
local prop = property(MonitorMgr)
prop:reader("host", nil)
prop:reader("port", 0)
prop:reader("rpc_server", nil)
prop:reader("http_server", nil)
prop:reader("monitor_nodes", {})
prop:reader("discovery", nil)
prop:reader("services", {})
prop:reader("log_page", "")

function MonitorMgr:__init()
    --创建rpc服务器
    local ip, port = env_addr("QUANTA_MONITOR_HOST")
    self.rpc_server = RpcServer(self, ip, port)
    --创建HTTP服务器
    local server = HttpServer(env_get("QUANTA_MONITOR_HTTP"))
    server:register_get("/", "on_log_page", self)
    server:register_get("/status", "on_monitor_status", self)
    server:register_post("/command", "on_monitor_command", self)
    server:register_post("/shutdown", "on_server_shutdown", self)
    --初始化变量
    self.host = ip
    self.http_server = server
    self.port = server:get_port()
    self.log_page = import("monitor/log_page.lua")
    --初始化定时器
    update_mgr:attach_minute(self)
    --加载服务发现
    self:load_discovery()
end

--定时更新
function MonitorMgr:on_minute()
    self.log_page = import("monitor/log_page.lua")
end

function MonitorMgr:load_discovery()
    local Discovery
    if DISCOVERY == "redis" then
        Discovery = import("monitor/redis_discovery.lua")
    else
        Discovery = import("monitor/nacos_discovery.lua")
    end
    self.discovery = Discovery(self.rpc_server)
end

function MonitorMgr:on_client_accept(client)
    --返回所有服务
    local services = self.discovery:get_services()
    for service_name, curr_services in pairs(services) do
        if next(curr_services) then
            self.rpc_server:send(client, "rpc_service_changed", service_name, curr_services, {})
        end
    end
end

-- 心跳
function MonitorMgr:on_client_beat(client)
    self.discovery:heartbeat(client.id)
end

function MonitorMgr:on_client_register(client, node)
    local token = client.token
    log_debug("[MonitorMgr][on_service_register] node:%s, token: %s", node.name, token)
    self.discovery:register(node)
    self.monitor_nodes[token] = node
end

-- 会话关闭回调
function MonitorMgr:on_client_error(client, token, err)
    log_info("[MonitorMgr][on_client_error] node:%s, token:%s", client.name, token)
    local node = self.monitor_nodes[token]
    if node then
        self.discovery:unregister(client.id)
        self.monitor_nodes[token] = nil
    end
end

--gm_page
function MonitorMgr:on_log_page(url, body, request)
    return self.log_page, {["Access-Control-Allow-Origin"] = "*"}
end

-- status查询
function MonitorMgr:on_monitor_status(url, querys, request)
    return self.monitor_nodes
end

--call
function MonitorMgr:call(token, rpc, ...)
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

--broadcast_all
function MonitorMgr:broadcast_all(rpc, ...)
    self.rpc_server:broadcast(rpc, ...)
end

--broadcast
function MonitorMgr:broadcast(service_id, rpc, ...)
    self.rpc_server:servicecast(service_id, "rpc_remote_message", rpc, ...)
    return {code = 0, msg = "broadcast all nodes server!"}
end

-- command处理
function MonitorMgr:on_monitor_command(url, body, request)
    log_debug("[MonitorMgr][on_monitor_command]: %s", body)
    --执行函数
    local function handler_cmd(jbody)
        local data_req = jdecode(jbody)
        if data_req.token then
            return self:call(data_req.token, data_req.rpc, data_req.data)
        end
        return self:broadcast(data_req.service_id, data_req.rpc, data_req.data)
    end
    --开始执行
    local ok, res = pcall(handler_cmd, body)
    if not ok then
        log_warn("[MonitorMgr:on_monitor_post] pcall: %s", res)
        return {code = 1, msg = res}
    end
    return res
end

-- 退出
function MonitorMgr:on_server_shutdown(url, body, request)
    log_debug("[MonitorMgr][on_server_shutdown] monitor quit")
    --发出退出进程
    self:broadcast_all("rpc_server_shutdown")
    -- 关闭会话连接
    timer_mgr:loop(SECOND_10_MS, function()
        log_warn("[MonitorMgr][on_server_shutdown]->service:%s", quanta.name)
        signal_quit()
    end)

    return "success"
end

quanta.monitor_mgr = MonitorMgr()

return MonitorMgr
