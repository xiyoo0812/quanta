--gm_mgr.lua
import("basic/cmdline.lua")

local HttpServer        = import("network/http_server.lua")

local log_err           = logger.err
local log_debug         = logger.debug
local sformat           = string.format
local tunpack           = table.unpack

local cmdline           = quanta.get("cmdline")
local event_mgr         = quanta.get("event_mgr")

local LOCAL             = quanta.enum("GMType", "LOCAL")
local SUCCESS           = quanta.enum("KernCode", "SUCCESS")

local GM_Mgr = singleton()
local prop = property(GM_Mgr)
prop:reader("gm_addr", "")
prop:reader("handlers", {})
prop:reader("services", {})
prop:reader("gm_status", false)
prop:reader("http_server", nil)

function GM_Mgr:__init()
    --监听事件
    event_mgr:add_listener(self, "rpc_register_command")
    event_mgr:add_listener(self, "rpc_execute_command")
    event_mgr:add_listener(self, "rpc_execute_message")

    --创建HTTP服务器
    local httpsvr = HttpServer(environ.get("QUANTA_GM_HTTP"))
    self.gm_addr = sformat("http://%s:%s", httpsvr:get_ip(),httpsvr:get_port())
    self.http_server = httpsvr
    --注册GM Handler
    self:register_handler(LOCAL, self, "exec_local_cmd")
    --是否开启GM功能
    if environ.status("QUANTA_GM_SERVER") then
        self.gm_status = true
        self:enable_webgm()
    end
end

--外部注册post请求
function GM_Mgr:register_post(url, handler, target)
    self.http_server:register_post(url, handler, target)
end

--外部注册get请求
function GM_Mgr:register_get(url, handler, target)
    self.http_server:register_get(url, handler, target)
end

--取消注册请求
function GM_Mgr:unregister_url(url)
    self.http_server:unregister(url)
end

function GM_Mgr:enable_webgm()
    self:register_get("/", "on_gm_page", self)
    self:register_get("/gmlist", "on_gmlist", self)
    self:register_post("/command", "on_command", self)
    self:register_post("/message", "on_message", self)
end

function GM_Mgr:disable_webgm()
    self:unregister_url("/")
    self:unregister_url("/gmlist")
    self:unregister_url("/command")
    self:unregister_url("/message")
end

--切换gm状态
function GM_Mgr:gm_switch(status)
    self.gm_status = status
    if self.gm_status then
        self:enable_webgm()
    else
        self:disable_webgm()
    end
    return status
end

--rpc请求
---------------------------------------------------------------------
--注册GM
function GM_Mgr:rpc_register_command(command_list, service_id)
    --同服务只执行一次
    if service_id and self.services[service_id] then
        return
    end
    for _, cmd in pairs(command_list) do
        cmdline:register_command(cmd.name, cmd.args, cmd.desc, cmd.gm_type, cmd.group, cmd.tip, cmd.example, service_id)
    end
    if service_id then
        self.services[service_id] = true
    end
    return SUCCESS
end

--执行gm, command：string
function GM_Mgr:rpc_execute_command(command)
    log_debug("[GM_Mgr][rpc_execute_command] command: {}", command)
    local res = self:exec_command(command)
    return SUCCESS, res
end

--执行gm, message: table
function GM_Mgr:rpc_execute_message(message)
    log_debug("[GM_Mgr][rpc_execute_message] message: {}", message)
    local res = self:exec_message(message)
    return SUCCESS, res
end

--http 回调
----------------------------------------------------------------------
--gm_page
function GM_Mgr:on_gm_page(url, body, params)
    local page = import("center/gm_page.lua")
    return page, {["Access-Control-Allow-Origin"] = "*", ["X-Frame-Options"]= "ALLOW_FROM"}
end

--gm列表
function GM_Mgr:on_gmlist(url, body, params)
    return { text = "GM指令", nodes = cmdline:get_displays() }
end

--后台GM调用，字符串格式
function GM_Mgr:on_command(url, body)
    log_debug("[GM_Mgr][on_command] body: {}", body)
    return self:exec_command(body.data)
end

--后台GM调用，table格式
function GM_Mgr:on_message(url, body)
    log_debug("[GM_Mgr][on_message] body: {}", body)
    return self:exec_message(body.data)
end

-------------------------------------------------------------------------
--后台GM执行，字符串格式
function GM_Mgr:exec_command(command)
    local fmtargs, err = cmdline:parser_command(command)
    if not fmtargs then
        return { code = 1, msg = err }
    end
    return self:dispatch_pre_command(fmtargs)
end

--后台GM执行，table格式
--message必须有name字段，作为cmd_name
function GM_Mgr:exec_message(message)
    local fmtargs, err = cmdline:parser_data(message)
    if not fmtargs then
        return { code = 1, msg = err }
    end
    return self:dispatch_pre_command(fmtargs)
end

--参数分发预处理
function GM_Mgr:dispatch_pre_command(fmtargs)
    local result = event_mgr:notify_listener("on_center_command", fmtargs.name, fmtargs.args)
    local status_ok, args = tunpack(result)
    --无额外处理
    if not status_ok then
        return self:dispatch_command(fmtargs.args, fmtargs.type, fmtargs.service)
    end
    return self:dispatch_command(args, fmtargs.type, fmtargs.service)
end

--分发command
function GM_Mgr:dispatch_command(cmd_args, gm_type, service_id)
    local handler = self.handlers[gm_type]
    if not handler then
        return { code = 1, msg = "gm_type error" }
    end
    local target, func_name = tunpack(handler)
    return target[func_name](target, service_id, tunpack(cmd_args))
end

--注册handler
function GM_Mgr:register_handler(gm_type, target, func_name)
    local callback_func = target[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_err("[GM_Mgr][register_handler] gm_type({}) handler not define!", gm_type)
        return
    end
    self.handlers[gm_type] = { target, func_name }
end

--local command
function GM_Mgr:exec_local_cmd(service_id, cmd_name, ...)
    local ok, res = tunpack(event_mgr:notify_listener(cmd_name, ...))
    if not ok then
        return { code = 1, msg = res }
    end
    return { code = 0, msg = res }
end

quanta.gm_mgr = GM_Mgr()

return GM_Mgr