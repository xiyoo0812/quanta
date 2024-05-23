--gm_mgr.lua
import("basic/cmdline.lua")
import("agent/online_agent.lua")

local HttpServer        = import("network/http_server.lua")

local log_err           = logger.err
local log_debug         = logger.debug
local sformat           = string.format
local tunpack           = table.unpack
local make_sid          = service.make_sid
local guid_index        = codec.guid_index

local online            = quanta.get("online")
local cmdline           = quanta.get("cmdline")
local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local router_mgr        = quanta.get("router_mgr")

local GLOBAL            = quanta.enum("GMType", "GLOBAL")
local SYSTEM            = quanta.enum("GMType", "SYSTEM")
local SERVICE           = quanta.enum("GMType", "SERVICE")
local LOCAL             = quanta.enum("GMType", "LOCAL")
local HASHKEY           = quanta.enum("GMType", "HASHKEY")
local PLAYER            = quanta.enum("GMType", "PLAYER")
local SUCCESS           = quanta.enum("KernCode", "SUCCESS")

local GM_Mgr = singleton()
local prop = property(GM_Mgr)
prop:reader("http_server", nil)
prop:reader("services", {})
prop:reader("gm_page", "")
prop:reader("gm_status", false)

function GM_Mgr:__init()
    --监听事件
    event_mgr:add_listener(self, "rpc_register_command")
    event_mgr:add_listener(self, "rpc_execute_command")
    event_mgr:add_listener(self, "rpc_execute_message")

    --创建HTTP服务器
    local server = HttpServer(environ.get("QUANTA_GM_HTTP"))
    self.http_server = server
    --是否开启GM功能
    if environ.status("QUANTA_GM_SERVER") then
        self.gm_status = true
        self:register_webgm()
    end
    --定时更新
    update_mgr:attach_second5(self)
    self:on_second5()
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

--定时更新
function GM_Mgr:on_second5()
    self.gm_page = import("center/gm_page.lua")
end

function GM_Mgr:register_webgm()
    self:register_get("/", "on_gm_page", self)
    self:register_get("/gmlist", "on_gmlist", self)
    self:register_post("/command", "on_command", self)
    self:register_post("/message", "on_message", self)
end

function GM_Mgr:unregister_webgm()
    self:unregister_url("/")
    self:unregister_url("/gmlist")
    self:unregister_url("/monitors")
    self:unregister_url("/command")
    self:unregister_url("/message")
end

--切换gm状态
function GM_Mgr:gm_switch(status)
    self.gm_status = status
    if self.gm_status then
        self:register_webgm()
    else
        self:unregister_webgm()
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
        local gm_type = cmd.gm_type or PLAYER
        cmdline:register_command(cmd.name, cmd.args, cmd.desc, gm_type, cmd.group, cmd.tip, cmd.example, service_id)
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

function GM_Mgr:on_service_close(id, name)
    log_debug("[GM_Mgr][on_service_close] node: {}-{}", name, id)
    self.monitors[id] = nil
end

function GM_Mgr:on_service_ready(id, name, info)
    log_debug("[GM_Mgr][on_service_ready] node: {}-{}, info: {}", name, id, info)
    self.monitors[id] = sformat("%s:%s", info.ip, info.port)
end

--http 回调
----------------------------------------------------------------------
--gm_page
function GM_Mgr:on_gm_page(url, body, params)
    return self.gm_page, {["Access-Control-Allow-Origin"] = "*", ["X-Frame-Options"]= "ALLOW_FROM"}
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

--分发command
function GM_Mgr:dispatch_command(cmd_args, gm_type, service_id)
    local callback = {
        [GLOBAL]    = GM_Mgr.exec_global_cmd,
        [SYSTEM]    = GM_Mgr.exec_system_cmd,
        [PLAYER]    = GM_Mgr.exec_player_cmd,
        [SERVICE]   = GM_Mgr.exec_service_cmd,
        [LOCAL]     = GM_Mgr.exec_local_cmd,
        [HASHKEY]   = GM_Mgr.exec_hash_cmd,
    }
    return callback[gm_type](self, service_id, tunpack(cmd_args))
end

--GLOBAL command
function GM_Mgr:exec_global_cmd(service_id, cmd_name, ...)
    local ok, codeoe, res = router_mgr:call_master(service_id, "rpc_command_execute" , cmd_name, ...)
    if not ok then
        log_err("[GM_Mgr][exec_global_cmd] rpc_command_execute failed! service_id:{},cmd_name={},code={},res={}", service_id, cmd_name, codeoe, res)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = res }
end

--system command
function GM_Mgr:exec_system_cmd(service_id, cmd_name, target_id, ...)
    local index = guid_index(target_id)
    local quanta_id = make_sid(service_id, index)
    local ok, codeoe, res = router_mgr:call_target(quanta_id, "rpc_command_execute" , cmd_name, target_id, ...)
    if not ok then
        log_err("[GM_Mgr][exec_system_cmd] rpc_command_execute failed! cmd_name={},code={},res={}", cmd_name, codeoe, res)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = res }
end

--service command
function GM_Mgr:exec_service_cmd(service_id, cmd_name, ...)
    local ok, codeoe = router_mgr:broadcast(service_id, "rpc_command_execute" , cmd_name, ...)
    if not ok then
        log_err("[GM_Mgr][exec_service_cmd] rpc_command_execute failed! cmd_name={}", cmd_name)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = "success" }
end

--hash command
function GM_Mgr:exec_hash_cmd(service_id, cmd_name, target_id, ...)
    local ok, codeoe, res = router_mgr:call_hash(service_id, target_id, "rpc_command_execute", cmd_name, target_id, ...)
    if not ok then
        log_err("[GM_Mgr][exec_hash_cmd] rpc_command_execute failed! cmd_name={}", cmd_name)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = res }
end

--local command
function GM_Mgr:exec_local_cmd(service_id, cmd_name, ...)
    local ok, res = tunpack(event_mgr:notify_listener(cmd_name, ...))
    if not ok then
        return { code = 1, msg = res }
    end
    return { code = 0, msg = res }
end

--player command
function GM_Mgr:exec_player_cmd(service_id, cmd_name, player_id, ...)
    if player_id == 0 then
        local ok, codeoe, res = router_mgr:call_world_random("rpc_command_execute", cmd_name, player_id, ...)
        if not ok then
            log_err("[GM_Mgr][exec_player_cmd] rpc_command_execute failed! cmd_name={} player_id={}", cmd_name, player_id)
            return { code = 1, msg = codeoe }
        end
        return { code = codeoe, msg = res }
    end
    local ok, codeoe, res = online:call_service(player_id, "rpc_command_execute", "world", cmd_name, player_id, ...)
    if not ok then
        log_err("[GM_Mgr][exec_player_cmd] rpc_command_execute failed! cmd_name={} player_id={}", cmd_name, player_id)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = res }
end

quanta.gm_mgr = GM_Mgr()

return GM_Mgr
