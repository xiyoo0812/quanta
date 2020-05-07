--monitor_mgr.lua
local ljson     = require("luacjson")
local http      = import("driver/http.lua")
local RpcServer = import("kernel/network/rpc_server.lua")
local HttpServer= import("kernel/network/http_server.lua")

local json_decode       = ljson.decode
local sformat           = string.format
local env_get           = environ.get
local log_info          = logger.info
local log_debug         = logger.debug
local serialize         = logger.serialize

local timer_mgr         = quanta.timer_mgr

local MonitorMgr = singleton()
local prop = property(MonitorMgr)
prop:accessor("url_host", "")
prop:accessor("rpc_server", nil)
prop:accessor("http_server", nil)

function RouterServer:__init()
    ljson.encode_sparse_array(true)
    --创建rpc服务器
    self.rpc_server = RpcServer()
    self.rpc_server:setup("QUANTA_MONITOR_ADDR")
    --监听事件
    self.rpc_server:add_listener(self, "on_socket_close")
    self.rpc_server:add_listener(self, "rpc_monitor_register")
    self.rpc_server:add_listener(self, "rpc_monitor_post")
    self.rpc_server:add_listener(self, "rpc_monitor_get")

    --创建HTTP服务器
    self.http_server = HttpServer()
    local function monitor_post(path, body, headers)
        return self:on_monitor_get(path, body, headers)
    end
    local function monitor_get(path, headers)
        return self:on_monitor_get(path, headers)
    end
    self.http_server:setup(env_get("QUANTA_MONITOR_HTTP"), monitor_post, monitor_get)

    --初始化网页后台地址
    self.url_host = env_get("QUANTA_WEBADMIN_HOST")
    -- 上报自己
    timer_mgr:once(100, function()
        self:forward_request("node_status", "call_post", {
            service = quanta.service_id,
            index   = quanta.index,
            id      = quanta.id,
            status  = 1,
        })
    end)
end

-- 会话关闭回调
function MonitorMgr:on_socket_close(client)
    log_info("[MonitorMgr][on_socket_close] node service:%s, id:%s", node.service, node.id)
    self:node_status(client, 0)
    self:forward_request("node_status", "call_post", {
        service = client.service,
        index   = client.index,
        id      = client.id,
        status  = 0,
    })
end

-- node上报Monitor
function MonitorMgr:rpc_monitor_register(client, quanta_id, service_id, quanta_index, quanta_name)
    log_debug("[MonitorMgr][rpc_monitor_register]: service:%s, id:%s", service_id, quanta_id)
    client.id = quanta_id
    client.name = quanta_name
    client.index = quanta_index
    client.service = service_id
    self:forward_request("node_status", "call_post", {
        service = service_id,
        index   = quanta_index,
        id      = quanta_id,
        status  = 1,
    })
end

-- node请求资源
function MonitorMgr:rpc_monitor_get(client, api_name, data)
    log_debug("[MonitorMgr][rpc_monitor_get]: client:%s, api_name:%s, data:%s", client.name, api_name, serialize(data))
    return self:forward_request(api_name, "call_get", data)
end

-- node上报数据
function MonitorMgr:rpc_monitor_post(client, api_name, data)
    log_debug("[MonitorMgr][rpc_monitor_post]: client:%s, api_name:%s, data:%s", client.name, api_name, serialize(data))
    return self:forward_request(api_name, "call_post", data)
end

-- node请求服务
function MonitorMgr:forward_request(api_name, method, data)
    local ok, code, res = http[method](sformat("%s/%s",self.url_host, api_name), data)
    log_debug("[MonitorMgr][service_request] ok:%s, api_name:%s, data:%s, code:%s, res:%s", ok, api_name, serialize(data), code, res)
    if not ok or code ~= 200 then
        return ok and code or 404
    end
    local body = json_decode(res)
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
function MonitorMgr:call(quanta_id, rpc, data)
    local client = self:get_client_by_id(quanta_id)
    if not client then
        return {code = 1, msg = "node not connect!"}
    end
    local ok, code, res = self.rpc_server:call(rpc, data)
    if not ok then
        return {code = 1, msg = "call moniotor node failed!"}
    end
    return {code = code, data = res }
end

--broadcast
function MonitorMgr:broadcast(rpc, service_id, data)
    for token, client in self.rpc_server:iterator() do
        if service_id == 0 or service_id == client.service then
            self.rpc_server:send(rpc, data)
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
        local data_req = json_decode(jbody)
        if data_req.service then
            return self:broadcast(data_req.rpc, data_req.service, data_req.data)
        else
            return self:call(data_req.id, data_req.rpc, data_req.data)
        end 
    end
    --开始执行
    local ok, res = pcall(handler_cmd, self, body)
    if ok then  -- 解析成功在协程中等待业务返回
        return res
    else        -- 解析错误直接返回
        log_warn("[MonitorMgr:on_monitor_post] pcall: %s", res)
        return {code = 1, msg = res}
    end
end

--http get 回调
function MonitorMgr:on_monitor_get(path, headers)
    log_debug("[MonitorMgr][on_monitor_get]: %s, %s", path, headers)
end

quanta.monitor_mgr = MonitorMgr()

return MonitorMgr
