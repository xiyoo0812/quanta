-- gm_mgr.lua
local ljson         = require("lcjson")
local HttpServer    = import("network/http_server.lua")

local log_debug     = logger.debug
local env_get       = environ.get
local jdecode       = ljson.decode

local robot_mgr     = quanta.get("robot_mgr")
local update_mgr    = quanta.get("update_mgr")

local AccordMgr = singleton()
local prop = property(AccordMgr)
prop:reader("http_server", nil)
prop:reader("accord_page", "")
prop:reader("accord_json_configs", "")
prop:reader("accord_lua_configs", {})

function AccordMgr:__init()
    -- 创建HTTP服务器
    local server = HttpServer(env_get("QUANTA_ACCORD_HTTP"))
    server:register_get("/", "on_accord_page", self)
    server:register_get("/config", "on_config", self)
    server:register_get("/message", "on_message", self)
    server:register_post("/create", "on_create", self)
    server:register_post("/destory", "on_destory", self)
    server:register_post("/runall", "on_runall", self)
    server:register_post("/run", "on_run", self)
    server:register_post("/upload", "on_upload", self)
    service.make_node(server:get_port())
    self.http_server = server
    -- 定时更新
    update_mgr:attach_second(self)
    self:on_second()
end

-- 定时更新
function AccordMgr:on_second()
    self.accord_page = import("robot/accord/accord_page.lua")
    local acc_conf = import("robot/accord/accord_conf.lua")
    self.accord_json_configs = acc_conf.json
    self.accord_lua_configs = acc_conf.lua
end

-- http 回调
----------------------------------------------------------------------
-- accord_page
function AccordMgr:on_accord_page(url, body, request)
    return self.accord_page, {
        ["Access-Control-Allow-Origin"] = "*"
    }
end

-- 拉取配置
function AccordMgr:on_config(url, body, request)
    return self.accord_json_configs
end

-- 拉取日志
function AccordMgr:on_message(url, body, request)
    local open_id = request.get_param("open_id")
    --log_debug("[AccordMgr][on_message] open_id: %s", open_id)
    return robot_mgr:get_accord_message(open_id)
end

-- monitor拉取
function AccordMgr:on_create(url, body, request)
    local jbody = jdecode(body)
    log_debug("[AccordMgr][on_create] body: %s", body)
    return robot_mgr:create_robot(jbody.ip, jbody.port, jbody.open_id, jbody.passwd)
end

-- 后台GM调用，字符串格式
function AccordMgr:on_destory(url, body, request)
    local jbody = jdecode(body)
    log_debug("[AccordMgr][on_destory] body: %s", body)
    return robot_mgr:destory_robot(jbody.open_id)
end

-- 客户端上传用例
function AccordMgr:on_upload(url, body, request)
    local jbody = jdecode(body)
    log_debug("[AccordMgr][on_upload] body: %s", body)

    local upload_script = jbody.data;
    local func, err = load(upload_script)
    if not func then
        log_debug("[AccordMgr][on_upload] err: %s", err)
        return
    end

    local acc_conf = func()
    self.accord_json_configs = acc_conf.json
    self.accord_lua_configs = acc_conf.lua
    return self.accord_json_configs
end

-- 后台GM调用，table格式
function AccordMgr:on_run(url, body, request)
    local jbody = jdecode(body)
    if jbody.cmd_id ~= 1001 then
        log_debug("[AccordMgr][on_run] body: %s", body)
    end
    return robot_mgr:run_accord_message(jbody.open_id, jbody.cmd_id, jbody.data)
end

-- 后台GM调用，table格式
function AccordMgr:on_runall(url, body, request)
    local jbody = jdecode(body)
    log_debug("[AccordMgr][on_runall] body: %s", body)
    return robot_mgr:run_accord_messages(jbody.open_id, jbody.data)
end

quanta.accord_mgr = AccordMgr()

return AccordMgr
