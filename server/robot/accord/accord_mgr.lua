-- accord_mgr.lua
import("robot/robot_mgr.lua")

local log_debug     = logger.debug
local ssplit        = string.split
local sformat       = string.format

local HttpServer    = import("network/http_server.lua")

local robot_mgr     = quanta.get("robot_mgr")

local ACCORD_URL    = environ.get("QUANTA_ACCORD_URL")

local AccordMgr = singleton()
local prop = property(AccordMgr)
prop:reader("http_server", nil)
prop:reader("accord_group", {}) -- 协议分组(解析proto)
prop:reader("srvlist_api", sformat("%s/server_mgr/query", ACCORD_URL)) -- 服务器列表api

function AccordMgr:__init()
    -- 创建HTTP服务器
    local server = HttpServer()
    server:listen(environ.addr("QUANTA_ACCORD_HTTP"))
    server:register_post("/run", "on_run", self)
    server:register_get("/message", "on_message", self)
    server:register_post("/create", "on_create", self)
    server:register_post("/destory", "on_destory", self)
    server:register_post("/get_config", "on_get_config", self)
    server:register_post("/random_end", "on_random_end", self)
    server:register_post("/random_start", "on_random_start", self)
    server:register_post("/random_proto", "on_random_proto", self)
    service.modify_host(server:get_port())
    self.http_server = server
end

-- http 回调
----------------------------------------------------------------------
-- 拉取日志
function AccordMgr:on_message(url, body, params)
    -- log_debug("[AccordMgr][on_message] open_id: {}", params.open_id)
    local robot = robot_mgr:get_robot(params.open_id)
    if robot then
        return { code = 0, msg = robot:get_messages() }
    end
    return { code = -1, msg = "robot not exist" }
end

-- 创角角色
function AccordMgr:on_create(url, body, params)
    log_debug("[AccordMgr][on_create] params:{}", params)
    local robot = robot_mgr:create_robot(body.ip, body.port, body.open_id, body.passwd)
    --绑定消息队列
    robot:bind_message_eueue()
    --执行登陆
    local ok, res = robot:login_server()
    return { code = ok and 0 or -1, msg = res }
end

-- 后台GM调用，字符串格式
function AccordMgr:on_destory(url, body, params)
    log_debug("[AccordMgr][on_destory] body:{}", body)
    return robot_mgr:destory_robot(body.open_id)
end

-- 后台GM调用，table格式
function AccordMgr:on_run(url, body)
    local data = body.data
    local cmd_id, open_id = body.cmd_id, body.open_id
    if cmd_id ~= 1001 then
        log_debug("[AccordMgr][on_run] body:{}", body)
    end
    local robot = robot_mgr:get_robot(open_id)
    if robot then
        local ok, res = robot:call(cmd_id, data)
        return { code = ok and 0 or -1, msg = res, req_open_id=open_id, req_cmd_id=cmd_id }
    end
    return { code = -1, msg = "robot not exist", req_open_id=open_id, req_cmd_id=cmd_id }
end

-- 获取配置
function AccordMgr:on_get_config(url, body)
    return { code = 0, srvlist_api=self.srvlist_api }
end


-- 开始随机发包
function AccordMgr:on_random_start(url, body, params)
    log_debug("[AccordMgr][on_random_start] params:{}", params)
    self:on_random_end()
    body.open_id = "random_open_id"
    body.passwd = "random_passwd"
    --拆分ip和端口
    local address = ssplit(body.address, ":")
    local ip, port = address[1], address[2]
    local robot = robot_mgr:create_robot(ip, port, body.open_id, body.passwd)
    --绑定消息队列
    robot:bind_message_eueue()
    local ok, res = 0, "success"
    if body.login then
        --执行登陆
        ok, res = robot:login_server()
    else
        if not robot:connect(ip, port, true) then
            return { code = -1, msg = "server connect failed!" }
        end
    end
    return { code = ok and 0 or -1, msg = res }
end

-- 结束随机发包
function AccordMgr:on_random_end(url, body, params)
    log_debug("[AccordMgr][on_random_end] body:{}", body)
    local open_id = "random_open_id"
    return robot_mgr:destory_robot(open_id)
end

-- 随机包
function AccordMgr:on_random_proto(url, body)
    local data = body.data
    body.open_id = "random_open_id"
    local cmd_id, open_id = body.cmd_id, body.open_id
    if cmd_id ~= 1001 then
        log_debug("[AccordMgr][on_random_proto] body:{}", body)
    end
    local robot = robot_mgr:get_robot(open_id)
    if robot then
        local ok, res = robot:call(cmd_id, data)
        return { code = ok and 0 or -1, msg = res, req_open_id=open_id, req_cmd_id=cmd_id }
    end
    return { code = -1, msg = "robot not exist", req_open_id=open_id, req_cmd_id=cmd_id }
end

quanta.accord_mgr = AccordMgr()

return AccordMgr
