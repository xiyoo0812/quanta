--gm_mgr.lua
import("utility/cmdline.lua")
local lhttp         = require("lhttp")
local ljson         = require("lcjson")
local lcrypt        = require("lcrypt")
local home_page     = import("admin/home_page.lua")
local HttpServer    = import("kernel/network/http_server.lua")

local jdecode       = ljson.decode
local guid_index    = lcrypt.guid_index
local tunpack       = table.unpack
local env_get       = environ.get
local env_number    = environ.number
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
prop:reader("app_id", 0)
prop:reader("chan_id", 0)
prop:reader("http_server", nil)
prop:reader("deploy", "local")
prop:reader("services", {})

function AdminMgr:__init()
    self.app_id = env_number("QUANTA_APP_ID")
    self.chan_id = env_number("QUANTA_CHAN_ID")

    --监听事件
    event_mgr:add_listener(self, "rpc_register_command")
    event_mgr:add_listener(self, "rpc_execute_command")

    --创建HTTP服务器
    local server = HttpServer(env_get("QUANTA_ADMIN_HTTP"))
    server:register_get("/", self.on_home_page, self)
    server:register_get("/gm", self.on_gminfo, self)
    server:register_get("/log", self.on_logger, self)
    server:register_post("/command", self.on_command, self)
    server:register_post("/monitor", self.on_monitor, self)
    server:register_post("/message", self.on_message, self)
    self.http_server = server

    --注册GM指令
    local cmd_list = {
        {gm_type = GMType.GLOBAL, name = "get_online_count", desc = "获取在线人数", args = ""},
        {gm_type = GMType.GLOBAL, name = "set_log_level", desc = "设置日志等级", args = "svr_name|string level|number"},
        {gm_type = GMType.GLOBAL, name = "get_account_info", desc = "获取账号信息", args = "open_id|string area_id|number"},
    }
    self:rpc_register_command(cmd_list, quanta.id)
end

--rpc请求
---------------------------------------------------------------------
--注册GM
function AdminMgr:rpc_register_command(command_list, service_id)
    --同服务只执行一次
    if self.services[service_id] then
        return
    end
    for _, command in pairs(command_list) do
        cmdline:register_command(command.name, command.args, command.desc, command.gm_type)
    end
    self.services[service_id] = true
    return KernCode.SUCCESS
end

--执行gm
function AdminMgr:rpc_execute_command(command)
    return self:exec_command(command)
end

--http 回调
----------------------------------------------------------------------
--home_page
function AdminMgr:on_home_page(url, body, headers)
    local response = lhttp.create_response()
    response:set_status(200)
    response:set_body(home_page)
    response:set_header("Access-Control-Allow-Origin", "*")
    return response
end

--gm信息
function AdminMgr:on_gminfo(url, body, headers)
    return cmdline:get_command_defines()
end

--后台GM调用
function AdminMgr:on_command(url, body, headers)
    log_debug("[AdminMgr][on_command] body：%s", body)
    local cmd_req = jdecode(body)
    return self:exec_command(cmd_req.data)
end

--后台接口调用
function AdminMgr:on_message(url, body, headers)
    log_debug("[AdminMgr][on_message] body：%s", body)
    local cmd_req = jdecode(body)
    local fmtargs, err = cmdline:parser_data(cmd_req.data)
    if not fmtargs then
        return { code = 1, msg = err }
    end
    return self:dispatch_command(fmtargs.args, fmtargs.type)
end

-------------------------------------------------------------------------
--后台GM调用，字符串格式
function AdminMgr:exec_command(command)
    local fmtargs, err = cmdline:parser_command(command)
    if not fmtargs then
        return { code = 1, msg = err }
    end
    return self:dispatch_command(fmtargs.args, fmtargs.type)
end

--分发command
function AdminMgr:dispatch_command(cmd_args, gm_type)
    if not gm_type then
        gm_type = GMType.PLAYER
    end
    if gm_type == GMType.GLOBAL then
        return self:exec_global_cmd(tunpack(cmd_args))
    elseif gm_type == GMType.PLAYER then
        return self:exec_player_cmd(tunpack(cmd_args))
    end
    return self:exec_service_cmd(gm_type, tunpack(cmd_args))
end

--GLOBAL command
function AdminMgr:exec_global_cmd(cmd_name, ...)
    local ok, codeoe, res = tunpack(event_mgr:notify_listener(cmd_name, ...))
    if not ok then
        log_err("[AdminMgr][exec_global_cmd] failed! res=%s", res)
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
    local ok, codeoe, res = router_mgr:rpc_transfer_message(player_id, "rpc_command_execute", player_id, ...)
    if not ok then
        log_err("[AdminMgr][exec_player_cmd] rpc_transfer_message(rpc_command_execute) failed! player_id=%s", player_id)
        return {code = 1, msg = codeoe }
    end
    return {code = codeoe, msg = res}
end

quanta.admin_mgr = AdminMgr()

return AdminMgr
