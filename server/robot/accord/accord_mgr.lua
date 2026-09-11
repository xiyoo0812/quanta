-- accord_mgr.lua
import("robot/robot_mgr.lua")

local log_debug     = logger.debug

local HttpServer    = import("network/http_server.lua")

local robot_mgr     = quanta.get("robot_mgr")

local AccordMgr = singleton()
local prop = property(AccordMgr)
prop:reader("http_server", nil)

function AccordMgr:__init()
    -- 创建HTTP服务器
    local server = HttpServer()
    server:listen(environ.addr("QUANTA_ACCORD_HTTP"))
    server:register_post("/case", "on_case", self)
    server:register_post("/node", "on_node", self)
    server:register_post("/stop", "on_stop", self)
    server:register_post("/message", "on_message", self)
    service.modify_host(server:get_port())
    self.http_server = server
end

function AccordMgr:load_robot(params, create)
    local robot = robot_mgr:get_robot(params.open_id)
    if robot then
        return robot
    end
    if create then
        return robot_mgr:create_robot(params.addr, params.port, params.open_id)
    end
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

-- 执行节点
function AccordMgr:on_node(url, body, params)
    local robot = self:load_robot(params, false)
    if robot then
        local ok, res = robot:run_node(body)
        return { code = ok and 0 or -1, msg = res }
    end
    return { code = -1, msg = "robot not exist" }
end

-- 执行用例
function AccordMgr:on_case(url, body, params)
    log_debug("[AccordMgr][on_case] params:{}", params)
    local robot = self:load_robot(params, true)
    local ok, res = robot:run_case(body)
    --执行登陆
    local ok, res = robot:login_server()
    return { code = ok and 0 or -1, msg = res }
end

-- 停止用例
function AccordMgr:on_stop(url, body, params)
    log_debug("[AccordMgr][on_stop] body:{}", body)
    return robot_mgr:destory_robot(body.open_id)
end

quanta.accord_mgr = AccordMgr()

return AccordMgr
