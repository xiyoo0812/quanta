--gm_mgr.lua
import("basic/cmdline.lua")
import("agent/online_agent.lua")

local ljson         = require("lcjson")
local lcrypt        = require("lcrypt")
local gm_page       = import("admin/gm_page.lua")
local HttpServer    = import("network/http_server.lua")

local jdecode       = ljson.decode
local guid_index    = lcrypt.guid_index
local tunpack       = table.unpack
local sformat       = string.format
local env_get       = environ.get
local make_sid      = service.make_sid
local log_err       = logger.err
local log_debug     = logger.debug

local online        = quanta.get("online")
local cmdline       = quanta.get("cmdline")
local monitor       = quanta.get("monitor")
local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")

local GLOBAL        = quanta.enum("GMType", "GLOBAL")
local SYSTEM        = quanta.enum("GMType", "SYSTEM")
local SERVICE       = quanta.enum("GMType", "SERVICE")
local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local AdminMgr = singleton()
local prop = property(AdminMgr)
prop:reader("http_server", nil)
prop:reader("cluster", "local")
prop:reader("services", {})
prop:reader("monitors", {})

function AdminMgr:__init()
    --监听事件
    event_mgr:add_listener(self, "rpc_register_command")
    event_mgr:add_listener(self, "rpc_execute_command")
    event_mgr:add_listener(self, "rpc_execute_message")

    --创建HTTP服务器
    local server = HttpServer(env_get("QUANTA_ADMIN_HTTP"))
    server:register_get("/", "on_gm_page", self)
    server:register_get("/gmlist", "on_gmlist", self)
    server:register_get("/monitors", "on_monitors", self)
    server:register_post("/command", "on_command", self)
    server:register_post("/monitor", "on_monitor", self)
    server:register_post("/message", "on_message", self)
    service.make_node(server:get_port())
    self.http_server = server

    --关注monitor
    monitor:watch_service_ready(self, "monitor")
    monitor:watch_service_close(self, "monitor")
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
    return SUCCESS
end

--执行gm, command：string
function AdminMgr:rpc_execute_command(command)
    local res = self:exec_command(command)
    return SUCCESS, res
end

--执行gm, message: table
function AdminMgr:rpc_execute_message(message)
    local res = self:exec_message(message)
    return SUCCESS, res
end

function AdminMgr:on_service_close(id, name)
    log_debug("[AdminMgr][on_service_close] node: %s-%s", name, id)
    self.monitors[id] = nil
end

function AdminMgr:on_service_ready(id, name, info)
    log_debug("[AdminMgr][on_service_ready] node: %s-%s, info: %s", name, id, info)
    self.monitors[id] = sformat("%s:%s", info.ip, info.port)
end

--http 回调
----------------------------------------------------------------------
--gm_page
function AdminMgr:on_gm_page(url, body, request)
    return gm_page, {["Access-Control-Allow-Origin"] = "*"}
end

--gm列表
function AdminMgr:on_gmlist(url, body, request)
    return cmdline:get_command_defines()
end

--后台GM调用，字符串格式
function AdminMgr:on_command(url, body, request)
    log_debug("[AdminMgr][on_command] body: %s", body)
    local cmd_req = jdecode(body)
    return self:exec_command(cmd_req.data)
end

--后台GM调用，table格式
function AdminMgr:on_message(url, body, request)
    log_debug("[AdminMgr][on_message] body: %s", body)
    local cmd_req = jdecode(body)
    return self:exec_message(cmd_req.data)
end

--monitor拉取
function AdminMgr:on_monitors(url, body, request)
    log_debug("[AdminMgr][on_monitors] body: %s", body)
    local monitors = {}
    for _, addr in pairs(self.monitors) do
        monitors[#monitors + 1] = addr
    end
    return monitors
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
--message必须有name字段，作为cmd_name
function AdminMgr:exec_message(message)
    local fmtargs, err = cmdline:parser_data(message)
    if not fmtargs then
        return { code = 1, msg = err }
    end
    return self:dispatch_command(fmtargs.args, fmtargs.type, fmtargs.service)
end

--分发command
function AdminMgr:dispatch_command(cmd_args, gm_type, service)
    if gm_type == GLOBAL then
        return self:exec_global_cmd(service, tunpack(cmd_args))
    elseif gm_type == SYSTEM then
        return self:exec_system_cmd(service, tunpack(cmd_args))
    elseif gm_type == SERVICE then
        return self:exec_service_cmd(service, tunpack(cmd_args))
    end
    return self:exec_player_cmd(tunpack(cmd_args))
end

--GLOBAL command
function AdminMgr:exec_global_cmd(service_id, cmd_name, ...)
    local ok, codeoe, res = router_mgr:call_master(service_id, "rpc_command_execute" , cmd_name, ...)
    if not ok then
        log_err("[AdminMgr][exec_global_cmd] call_master(rpc_command_execute) failed! service_id=%s", service_id)
        return {code = 1, msg = codeoe }
    end
    return {code = codeoe, msg = res}
end

--system command
function AdminMgr:exec_system_cmd(service_id, cmd_name, target_id, ...)
    local index = guid_index(target_id)
    local quanta_id = make_sid(service_id, index)
    local ok, codeoe, res = router_mgr:call_target(quanta_id, "rpc_command_execute" , cmd_name, target_id, ...)
    if not ok then
        log_err("[AdminMgr][exec_system_cmd] call_target(rpc_command_execute) failed! target_id=%s", target_id)
        return {code = 1, msg = codeoe }
    end
    return {code = codeoe, msg = res}
end

--service command
function AdminMgr:exec_service_cmd(service_id, cmd_name, target_id, ...)
    local ok, codeoe, res = router_mgr:call_hash(service_id, target_id, "rpc_command_execute" , cmd_name, target_id, ...)
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
    local ok, codeoe, res = online:call_lobby(player_id, "rpc_command_execute", cmd_name, player_id, ...)
    if not ok then
        log_err("[AdminMgr][exec_player_cmd] rpc_call_lobby(rpc_command_execute) failed! player_id=%s", player_id)
        return {code = 1, msg = codeoe }
    end
    return {code = codeoe, msg = res}
end

quanta.admin_mgr = AdminMgr()

return AdminMgr
