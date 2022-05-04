--monitor_mgr.lua
import("network/http_client.lua")
local ljson         = require("lcjson")
local log_page      = import("monitor/log_page.lua")
local RpcServer     = import("network/rpc_server.lua")
local HttpServer    = import("network/http_server.lua")

local qget          = quanta.get
local env_get       = environ.get
local env_addr      = environ.addr
local log_warn      = logger.warn
local log_info      = logger.info
local log_debug     = logger.debug
local jdecode       = ljson.decode
local sformat       = string.format

local event_mgr     = qget("event_mgr")
local thread_mgr    = qget("thread_mgr")
local http_client   = qget("http_client")

local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")

local MonitorMgr = singleton()
local prop = property(MonitorMgr)
prop:reader("rpc_server", nil)
prop:reader("http_server", nil)
prop:reader("monitor_nodes", {})

function MonitorMgr:__init()
    --创建rpc服务器
    local ip, port = env_addr("QUANTA_MONITOR_HOST")
    self.rpc_server = RpcServer()
    self.rpc_server:setup(ip, port)
    --监听事件
    event_mgr:add_listener(self, "on_socket_info")
    event_mgr:add_listener(self, "on_socket_error")
    event_mgr:add_listener(self, "on_socket_accept")

    --创建HTTP服务器aaa
    local server = HttpServer(env_get("QUANTA_MONITOR_HTTP"))
    server:register_get("/", "on_log_page", self)
    server:register_get("/status", "on_monitor_status", self)
    server:register_post("/command", "on_monitor_command", self)
    self.http_server = server

    --上报自己
    local admin_url = env_get("QUANTA_ADMIN_HTTP")
    if admin_url then
        local host = env_get("QUANTA_HOST_IP")
        local purl = sformat("%s/monitor", admin_url)
        local http_addr = sformat("%s:%d", host, server:get_port())
        thread_mgr:success_call(SECOND_MS, function()
            local ok, status = http_client:call_post(purl, { addr = http_addr })
            if ok and status == 200 then
                return true
            end
            return false
        end)
    end
end

function MonitorMgr:on_socket_accept(client)
end

-- 会话信息
function MonitorMgr:on_socket_info(client, node_info)
    log_info("[MonitorMgr][on_socket_info] node token:%s", client.token)
    node_info.token = client.token
    self.monitor_nodes[client.token] = node_info
end

-- 会话关闭回调
function MonitorMgr:on_socket_error(client, token, err)
    log_info("[MonitorMgr][on_socket_error] node name:%s, id:%s, token:%s", client.name, client.id, token)
    self.monitor_nodes[client.token] = nil
end

--gm_page
function MonitorMgr:on_log_page(url, body, headers)
    local ret_headers = {["Access-Control-Allow-Origin"] = "*"}
    return self.http_server:build_response(200, log_page, ret_headers)
end

-- status查询
function MonitorMgr:on_monitor_status(url, querys, headers)
    return self.monitor_nodes
end

--call
function MonitorMgr:call(token, rpc, ...)
    local client = self.rpc_server:get_client(token)
    if not client then
        return {code = 1, msg = "node not connect!"}
    end
    local ok, code, res = self.rpc_server:call(client, rpc, ...)
    if not ok then
        return {code = 1, msg = "call moniotor node failed!"}
    end
    return {code = code, msg = res }
end

--broadcast
function MonitorMgr:broadcast(rpc, service_id, ...)
    for token, client in self.rpc_server:iterator() do
        if service_id == 0 or service_id == client.service_id then
            self.rpc_server:send(client, rpc, ...)
        end
    end
    return {code = 0, msg = "broadcast all nodes server!"}
end

-- command处理
function MonitorMgr:on_monitor_command(url, body, headers)
    log_debug("[MonitorMgr][on_monitor_command]: %s", body)
    --执行函数
    local function handler_cmd(jbody)
        local data_req = jdecode(jbody)
        if data_req.token then
            return self:call(data_req.token, data_req.rpc, data_req.data)
        end
        return self:broadcast(data_req.rpc, data_req.service_id, data_req.data)
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
