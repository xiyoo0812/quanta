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
local tdiff         = qtable.diff

local nacos         = quanta.get("nacos")
local update_mgr    = quanta.get("update_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local MonitorMgr = singleton()
local prop = property(MonitorMgr)
prop:reader("host", nil)
prop:reader("port", 0)
prop:reader("rpc_server", nil)
prop:reader("http_server", nil)
prop:reader("monitor_nodes", {})
prop:reader("services", {})
prop:reader("log_page", "")

function MonitorMgr:__init()
    --创建rpc服务器
    local ip, port = env_addr("QUANTA_MONITOR_HOST")
    self.rpc_server = RpcServer(self, ip, port)
    --创建HTTP服务器aaa
    local server = HttpServer(env_get("QUANTA_MONITOR_HTTP"))
    server:register_get("/", "on_log_page", self)
    server:register_get("/status", "on_monitor_status", self)
    server:register_post("/command", "on_monitor_command", self)
    self.port = server:get_port()
    self.http_server = server
    self.host = ip
    --初始化定时器
    update_mgr:attach_minute(self)
    update_mgr:attach_second5(self)
    self:on_minute()
    --注册自己
    thread_mgr:fork(function()
        nacos:modify_switchs("healthCheckEnabled", "false")
        nacos:modify_switchs("autoChangeHealthCheckEnabled", "false")
        local metadata = { region = quanta.region, group = quanta.group, id = quanta.id, name = quanta.name }
        nacos:regi_instance(quanta.service_name, ip, self.port, nil, metadata)
    end)
end

--定时更新
function MonitorMgr:on_minute()
    self.log_page = import("monitor/log_page.lua")
end

function MonitorMgr:on_second5()
    for _, service_name in pairs(nacos:query_services() or {}) do
        local curr = nacos:query_instances(service_name)
        if curr then
            local old = self.services[service_name]
            local sadd, sdel = tdiff(old or {}, curr)
            if next(sadd) or next(sdel) then
                log_debug("[MonitorMgr][on_second5] sadd:%s, sdel: %s", sadd, sdel)
                self.rpc_server:broadcast("rpc_service_changed", service_name, sadd, sdel)
                self.services[service_name] = curr
            end
        end
    end
    --发送心跳
    nacos:sent_beat(quanta.service_name, self.host, self.port)
end

function MonitorMgr:on_client_accept(client)
end

-- 心跳
function MonitorMgr:on_client_beat(client)
    local node = self.monitor_nodes[client.token]
    if node then
        if not node.status then
            local metadata = { region = node.region, group = node.group, id = node.id, name = node.name }
            node.status = nacos:regi_instance(node.service_name, node.host, node.port, nil, metadata)
        end
        nacos:sent_beat(node.service_name, node.host, node.port)
    end
end

function MonitorMgr:on_client_register(client, node)
    local token = client.token
    log_debug("[MonitorMgr][on_service_register] node:%s, token: %s", node.name, token)
    local metadata = { region = node.region, group = node.group, id = node.id, name = node.name }
    local status = nacos:regi_instance(node.service_name, node.host, node.port, nil, metadata)
    self.monitor_nodes[token] = node
    node.status = status
    node.token = token
    --返回所有服务
    for service_name, curr_services in pairs(self.services) do
        if next(curr_services) then
            self.rpc_server:send(client, "rpc_service_changed", service_name, curr_services, {})
        end
    end
end

-- 会话关闭回调
function MonitorMgr:on_client_error(client, token, err)
    log_info("[MonitorMgr][on_client_error] node:%s, token:%s", client.name, token)
    local node = self.monitor_nodes[token]
    if node then
        nacos:del_instance(node.service_name, node.host, node.port)
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

quanta.monitor_mgr = MonitorMgr()

return MonitorMgr
