--monitor_mgr.lua
import("kernel/network/http_client.lua")
local ljson     = require("lcjson")
local RpcServer = import("kernel/network/rpc_server.lua")
local HttpServer= import("kernel/network/http_server.lua")

local jdecode       = ljson.decode
local jencode       = ljson.encode
local sformat       = string.format
local env_get       = environ.get
local env_addr      = environ.addr
local env_number    = environ.number
local log_warn      = logger.warn
local log_info      = logger.info
local log_debug     = logger.debug

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local http_client   = quanta.get("http_client")

local PeriodTime    = enum("PeriodTime")

local MonitorMgr = singleton()
local prop = property(MonitorMgr)
prop:reader("app_id", 0)
prop:reader("chan_id", 0)
prop:reader("url_host", "")
prop:reader("rpc_server", nil)
prop:reader("http_server", nil)
prop:reader("monitor_nodes", {})

function MonitorMgr:__init()
    self.app_id = env_number("QUANTA_APP_ID")
    self.chan_id = env_number("QUANTA_CHAN_ID")
    --创建rpc服务器
    local ip, port = env_addr("QUANTA_MONITOR_HOST")
    self.rpc_server = RpcServer()
    self.rpc_server:setup(ip, port)
    --监听事件
    event_mgr:add_listener(self, "on_socket_info")
    event_mgr:add_listener(self, "on_socket_error")

    --创建HTTP服务器
    local server = HttpServer(env_get("QUANTA_MONITOR_HTTP"))
    server:register_get("/status", self.on_monitor_status, self)
    server:register_post("/command", self.on_monitor_command, self)
    self.http_server = server

    --初始化管理节点地址
    self.url_host = env_get("QUANTA_ADMIN_HTTP")
end

--上报节点状态
function MonitorMgr:post_node_status(client, status)
    local data = {
        app_id  = self.app_id,
        deploy  = self.deploy,
        service = client.service_id,
        index   = client.index,
        id      = client.id,
        status  = status,
    }
    thread_mgr:success_call(PeriodTime.SECOND_MS, function()
        if self:forward_request("node_status", "call_post", jencode(data)) == 0 then
            log_info("[MonitorMgr][post_node_status] node : %s success!", client.name)
            return true
        end
        return false
    end)
end

-- 会话信息
function MonitorMgr:on_socket_info(client, node_info)
    log_info("[MonitorMgr][on_socket_info] node token:%s", client.token)
    node_info.token = client.token
    node_info.app_id = self.app_id
    node_info.chan_id = self.chan_id
    self.moniotor_nodes[client.token] = node_info
end

-- 会话关闭回调
function MonitorMgr:on_socket_error(client, token, err)
    log_info("[MonitorMgr][on_socket_error] node name:%s, id:%s, token:%s", client.name, client.id, token)
    self.moniotor_nodes[client.token] = nil
end

-- node请求服务
function MonitorMgr:forward_request(api_name, method, ...)
    local ok, code, res = http_client[method](http_client, sformat("%s/runtime/%s", self.url_host, api_name), ...)
    if not ok or code ~= 200 then
        return ok and code or 404
    end
    local body = jdecode(res)
    if body.code ~= 0 then
        return body.code, body.msg
    end
    return body.code, body.data
end

-- status查询
function MonitorMgr:on_monitor_status(url, querys, headers)
    return { code = 0, msg = self.moniotor_nodes }
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
    return {code = code, data = res }
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
    log_debug("[MonitorMgr][on_monitor_command]: %s, %s, %s", url, body, headers)
    --执行函数
    local function handler_cmd(jbody)
        local data_req = jdecode(jbody)
        if data_req.service_id then
            return self:broadcast(data_req.rpc, data_req.service_id, data_req.data, data_req.message)
        end
        return self:call(data_req.token, data_req.rpc, data_req.data, data_req.message)
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
