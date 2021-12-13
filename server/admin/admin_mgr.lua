--gm_mgr.lua
import("utility/cmdline.lua")
local ljson         = require("lcjson")
local lcrypt        = require("lcrypt")
local home_page     = import("admin/home_page.lua")
local HttpServer    = import("kernel/network/http_server.lua")

local jdecode       = ljson.decode
local guid_index    = lcrypt.guid_index
local tunpack       = table.unpack
local env_get       = environ.get
local smake_id      = service.make_id
local log_err       = logger.err
local log_debug     = logger.debug

local GMType        = enum("GMType")
local KernCode      = enum("KernCode")

local cmdline       = quanta.get("cmdline")
local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")

local AdminMgr = class()
local prop = property(AdminMgr)
prop:reader("http_server", nil)
prop:reader("deploy", "local")
prop:reader("services", {})

function AdminMgr:__init()
    --监听事件
    event_mgr:add_listener(self, "rpc_register_command")
    event_mgr:add_listener(self, "rpc_execute_command")
    event_mgr:add_listener(self, "rpc_execute_message")

    --创建HTTP服务器
    local server = HttpServer(env_get("QUANTA_ADMIN_HTTP"))
    server:register_get("/", self.on_home_page, self)
    server:register_get("/log", self.on_logger, self)
    server:register_get("/gmlist", self.on_gmlist, self)
    server:register_post("/command", self.on_command, self)
    server:register_post("/monitor", self.on_monitor, self)
    server:register_post("/message", self.on_message, self)
    self.http_server = server
end

--rpc请求
---------------------------------------------------------------------
--注册GM
function AdminMgr:rpc_register_command(command_list, service_id)
    --同服务只执行一次
    if self.services[service_id] then
        return
    end
    for _, cmd in pairs(command_list) do
        cmdline:register_command(cmd.name, cmd.args, cmd.desc, cmd.gm_type, service_id)
    end
    self.services[service_id] = true
    return KernCode.SUCCESS
end

--执行gm, command：string
function AdminMgr:rpc_execute_command(command)
    return self:exec_command(command)
end

--执行gm, message: table
function AdminMgr:rpc_execute_message(message)
    return self:exec_message(message)
end

--http 回调
----------------------------------------------------------------------
--home_page
function AdminMgr:on_home_page(url, body, headers)
    local ret_headers = {["Access-Control-Allow-Origin"] = "*"}
    return self.http_server:build_response(200, home_page, ret_headers)
end

--gm列表
function AdminMgr:on_gmlist(url, body, headers)
    return cmdline:get_command_defines()
end

--后台GM调用，字符串格式
function AdminMgr:on_command(url, body, headers)
    log_debug("[AdminMgr][on_command] body：%s", body)
    local cmd_req = jdecode(body)
    return self:exec_command(cmd_req.data)
end

--后台GM调用，table格式
function AdminMgr:on_message(url, body, headers)
    log_debug("[AdminMgr][on_message] body：%s", body)
    local cmd_req = jdecode(body)
    return self:exec_message(cmd_req.data)
end

-------------------------------------------------------------------------
--后台GM执行，字符串格式
function AdminMgr:exec_command(command)
    local fmtargs, err = cmdline:parser_command(command)
    if not fmtargs then
        return { code = 1, msg = err }
    end
    return self:dispatch_command(fmtargs.args, fmtargs.type, fmtargs.service)
end

--后台GM执行，table格式
function AdminMgr:exec_message(message)
    local fmtargs, err = cmdline:parser_data(message)
    if not fmtargs then
        return { code = 1, msg = err }
    end
    return self:dispatch_command(fmtargs.args, fmtargs.type, fmtargs.service)
end

--分发command
function AdminMgr:dispatch_command(cmd_args, gm_type, service)
    if gm_type == GMType.GLOBAL then
        return self:exec_global_cmd(service, tunpack(cmd_args))
    elseif gm_type == GMType.SERVICE then
        return self:exec_service_cmd(service, tunpack(cmd_args))
    end
    return self:exec_player_cmd(tunpack(cmd_args))
end

--GLOBAL command
function AdminMgr:exec_global_cmd(service_id, cmd_name, ...)
    local ok, codeoe, res = router_mgr:call_random(service_id, "rpc_command_execute" , cmd_name, ...)
    if not ok then
        log_err("[AdminMgr][exec_global_cmd] call_random(rpc_command_execute) failed! service_id=%s", service_id)
        return {code = 1, msg = codeoe }
    end
    return {code = codeoe, msg = res}
end

--service command
function AdminMgr:exec_service_cmd(service_id, cmd_name, target_id, ...)
    local index = guid_index(target_id)
    local quanta_id = smake_id(service_id, index)
    local ok, codeoe, res = router_mgr:call_target(quanta_id, "rpc_command_execute" , cmd_name, target_id, ...)
    if not ok then
        log_err("[AdminMgr][exec_service_cmd] call_target(rpc_command_execute) failed! target_id=%s", target_id)
        return {code = 1, msg = codeoe }
    end
    return {code = codeoe, msg = res}
end

--player command
function AdminMgr:exec_player_cmd(cmd_name, player_id, ...)
    if player_id == 0 then
        local ok, codeoe, res = router_mgr:call_lobby_random("rpc_command_execute", cmd_name, player_id, ...)
        if not ok then
            log_err("[AdminMgr][exec_player_cmd] call_lobby_random(rpc_command_execute) failed! player_id=%s", player_id)
            return {code = 1, msg = codeoe }
        end
        return {code = codeoe, msg = res}
    end
    local ok, codeoe, res = router_mgr:rpc_transfer_message(player_id, "rpc_command_execute", cmd_name, player_id, ...)
    if not ok then
        log_err("[AdminMgr][exec_player_cmd] rpc_transfer_message(rpc_command_execute) failed! player_id=%s", player_id)
        return {code = 1, msg = codeoe }
    end
    return {code = codeoe, msg = res}
end

quanta.admin_mgr = AdminMgr()

return AdminMgr
