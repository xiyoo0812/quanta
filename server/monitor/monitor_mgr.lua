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
prop:reader("deploy", "local")
prop:reader("url_host", "")
prop:reader("rpc_server", nil)
prop:reader("http_server", nil)

function MonitorMgr:__init()
    self.deploy = env_get("QUANTA_DEPLOY")
    self.app_id = env_number("QUANTA_APP_ID")
    self.chan_id = env_number("QUANTA_CHAN_ID")
    --创建rpc服务器
    local ip, port = env_addr("QUANTA_MONITOR_HOST")
    self.rpc_server = RpcServer()
    self.rpc_server:setup(ip, port)
    --监听事件
    event_mgr:add_listener(self, "on_socket_error")
    event_mgr:add_listener(self, "on_socket_accept")
    event_mgr:add_listener(self, "rpc_monitor_register")
    event_mgr:add_listener(self, "rpc_monitor_post")
    event_mgr:add_listener(self, "rpc_monitor_get")

    --创建HTTP服务器
    self.http_server = HttpServer()
    local function monitor_post(path, body, headers)
        return self:on_monitor_post(path, body, headers)
    end
    local function monitor_get(path, querys, headers)
        return self:on_monitor_get(path, querys, headers)
    end
    self.http_server:setup(env_get("QUANTA_MONITOR_HTTP"), monitor_post, monitor_get)

    --初始化网页后台地址
    self.url_host = env_get("QUANTA_WEBADMIN_HOST")
    -- 上报自己
    self:post_node_status(quanta, 1)
end

--上报节点状态
function MonitorMgr:post_node_status(client, status)
    local data = {
        app_id  = self.app_id,
        chan_id = self.chan_id,
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

-- 会话accept回调
function MonitorMgr:on_socket_accept(client)
    log_info("[MonitorMgr][on_socket_accept] node token:%s", client.token)
end

-- 会话关闭回调
function MonitorMgr:on_socket_error(client)
    log_info("[MonitorMgr][on_socket_error] node name:%s, id:%s, token:%s", client.name, client.id, client.token)
    self:post_node_status(client, 0)
end

-- node上报Monitor
function MonitorMgr:rpc_monitor_register(client, quanta_id, service_id, quanta_index, quanta_name)
    log_debug("[MonitorMgr][rpc_monitor_register]: service:%s, qname=%s, qindex=%s, qid:%s",
        service_id, quanta_name, quanta_index, quanta_id)
    client.id = quanta_id
    client.name = quanta_name
    client.index = quanta_index
    client.service = service_id
    self:post_node_status(client, 1)
end

-- node请求资源
function MonitorMgr:rpc_monitor_get(client, api_name, querys)
    querys.app_id, querys.chan_id, querys.deploy  = self.app_id, self.chan_id, self.deploy
    --log_debug("[MonitorMgr][rpc_monitor_get]: client:%s, api_name:%s, querys:%s", client.name, api_name, jencode(querys))
    return self:forward_request(api_name, "call_get", querys)
end

-- node上报数据
function MonitorMgr:rpc_monitor_post(client, api_name, data)
    data.app_id, data.chan_id, data.deploy  = self.app_id, self.chan_id, self.deploy
    --log_debug("[MonitorMgr][rpc_monitor_post]: client:%s, api_name:%s, data:%s", client.name, api_name, jencode(data))
    return self:forward_request(api_name, "call_post", data)
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

--获取client
function MonitorMgr:get_client_by_id(quanta_id)
    for token, client in self.rpc_server:iterator() do
        if client.id == quanta_id then
            return client
        end
    end
end

--call
function MonitorMgr:call(quanta_id, rpc, ...)
    local client = self:get_client_by_id(quanta_id)
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
        if service_id == 0 or service_id == client.service then
            self.rpc_server:send(client, rpc, ...)
        end
    end
    return {code = 0, msg = "broadcast all nodes server!"}
end

--http post 回调
function MonitorMgr:on_monitor_post(path, body, headers)
    log_debug("[MonitorMgr][on_monitor_post]: %s, %s, %s", path, body, headers)
    if path ~= "/command" then
        return {code = 1, msg = "path not exist!"}
    end
    --执行函数
    local function handler_cmd(jbody)
        local data_req = jdecode(jbody)
        if data_req.service then
            return self:broadcast(data_req.rpc, data_req.service, data_req.data, data_req.message)
        end
        return self:call(data_req.svr_id, data_req.rpc, data_req.data, data_req.message)
    end
    --开始执行
    local ok, res = pcall(handler_cmd, body)
    if not ok then  
        log_warn("[MonitorMgr:on_monitor_post] pcall: %s", res)
        return {code = 1, msg = res}
    end
    return res
end

--http get 回调
function MonitorMgr:on_monitor_get(path, querys, headers)
    log_debug("[MonitorMgr][on_monitor_get]: %s, %s, %s", path, querys, headers)
    return {code = 1, msg = "path not exist!"}
end

quanta.monitor_mgr = MonitorMgr()

return MonitorMgr
