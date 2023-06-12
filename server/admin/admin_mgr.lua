--gm_mgr.lua
import("basic/cmdline.lua")
import("agent/online_agent.lua")

local ljson             = require("lcjson")
local lcodec            = require("lcodec")
local HttpServer        = import("network/http_server.lua")

local log_err           = logger.err
local log_debug         = logger.debug
local sformat           = string.format
local tunpack           = table.unpack
local tinsert           = table.insert
local make_sid          = service.make_sid
local jdecode           = ljson.decode
local guid_index        = lcodec.guid_index

local online            = quanta.get("online")
local cmdline           = quanta.get("cmdline")
local monitor           = quanta.get("monitor")
local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local router_mgr        = quanta.get("router_mgr")

local GLOBAL            = quanta.enum("GMType", "GLOBAL")
local SYSTEM            = quanta.enum("GMType", "SYSTEM")
local SERVICE           = quanta.enum("GMType", "SERVICE")
local OFFLINE           = quanta.enum("GMType", "OFFLINE")
local LOCAL             = quanta.enum("GMType", "LOCAL")
local HASHKEY           = quanta.enum("GMType", "HASHKEY")
local PLAYER            = quanta.enum("GMType", "PLAYER")
local SUCCESS           = quanta.enum("KernCode", "SUCCESS")
local PLAYER_NOT_EXIST  = quanta.enum("KernCode", "PLAYER_NOT_EXIST")

local AdminMgr = singleton()
local prop = property(AdminMgr)
prop:reader("http_server", nil)
prop:reader("cluster", "local")
prop:reader("services", {})
prop:reader("monitors", {})
prop:reader("gm_page", "")

function AdminMgr:__init()
    --监听事件
    event_mgr:add_listener(self, "rpc_register_command")
    event_mgr:add_listener(self, "rpc_execute_command")
    event_mgr:add_listener(self, "rpc_execute_message")

    --创建HTTP服务器
    local server = HttpServer(environ.get("QUANTA_ADMIN_HTTP"))
    service.make_node(server:get_port())
    self.http_server = server
    --是否开启GM功能
    if environ.status("QUANTA_ADMIN_GM") then
        server:register_get("/", "on_gm_page", self)
        server:register_get("/gmlist", "on_gmlist", self)
        server:register_get("/monitors", "on_monitors", self)
        server:register_post("/command", "on_command", self)
        server:register_post("/message", "on_message", self)
    end
    --关注monitor
    monitor:watch_service_ready(self, "monitor")
    monitor:watch_service_close(self, "monitor")
    --定时更新
    update_mgr:attach_second5(self)
    self:on_second5()
end

--外部注册post请求
function AdminMgr:register_post(url, handler, target)
    self.http_server:register_post(url, handler, target)
end

--外部注册get请求
function AdminMgr:register_get(url, handler, target)
    self.http_server:register_get(url, handler, target)
end

--定时更新
function AdminMgr:on_second5()
    self.gm_page = import("admin/gm_page.lua")
end

-- 事件请求
function AdminMgr:on_register_command(command_list, service_id)
    self:rpc_register_command(command_list, service_id)
    return SUCCESS
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
        local gm_type = cmd.gm_type or PLAYER
        cmdline:register_command(cmd.name, cmd.args, cmd.desc, gm_type, cmd.group, cmd.tip, cmd.example, service_id)
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
    return self.gm_page, {["Access-Control-Allow-Origin"] = "*"}
end

--gm列表
function AdminMgr:on_gmlist(url, body, request)
    return { text = "GM指令", nodes = cmdline:get_displays() }
end

--monitor拉取
function AdminMgr:on_monitors(url, body, request)
    log_debug("[AdminMgr][on_monitors] body: %s", body)
    local nodes = {}
    for _, addr in pairs(self.monitors) do
        tinsert(nodes, { text = addr, tag = "log" })
    end
    return { text = "在线日志", nodes = nodes }
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

-------------------------------------------------------------------------
--参数分发预处理
function AdminMgr:dispatch_pre_command(fmtargs)
    local result = event_mgr:notify_listener("on_admin_command", fmtargs.name, fmtargs.args)
    local _, status_ok, args = tunpack(result)
    --无额外处理
    if not status_ok then
        return self:dispatch_command(fmtargs.args, fmtargs.type, fmtargs.service)
    end

    return self:dispatch_command(args, fmtargs.type, fmtargs.service)
end

--后台GM执行，字符串格式
function AdminMgr:exec_command(command)
    local fmtargs, err = cmdline:parser_command(command)
    if not fmtargs then
        return { code = 1, msg = err }
    end
    return self:dispatch_pre_command(fmtargs)
end

--后台GM执行，table格式
--message必须有name字段，作为cmd_name
function AdminMgr:exec_message(message)
    local fmtargs, err = cmdline:parser_data(message)
    if not fmtargs then
        return { code = 1, msg = err }
    end
    return self:dispatch_pre_command(fmtargs)
end

--分发command
function AdminMgr:dispatch_command(cmd_args, gm_type, service_id)
    local callback = {
        [GLOBAL]    = AdminMgr.exec_global_cmd,
        [SYSTEM]    = AdminMgr.exec_system_cmd,
        [PLAYER]    = AdminMgr.exec_player_cmd,
        [SERVICE]   = AdminMgr.exec_service_cmd,
        [OFFLINE]   = AdminMgr.exec_offline_cmd,
        [LOCAL]     = AdminMgr.exec_local_cmd,
        [HASHKEY]   = AdminMgr.exec_hash_cmd,
    }
    return callback[gm_type](self, service_id, tunpack(cmd_args))
end

--GLOBAL command
function AdminMgr:exec_global_cmd(service_id, cmd_name, ...)
    local ok, codeoe, res = router_mgr:call_master(service_id, "rpc_command_execute" , cmd_name, ...)
    if not ok then
        log_err("[AdminMgr][exec_global_cmd] rpc_command_execute failed! service_id:%s, cmd_name=%s", service_id, cmd_name)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = res }
end

--system command
function AdminMgr:exec_system_cmd(service_id, cmd_name, target_id, ...)
    local index = guid_index(target_id)
    local quanta_id = make_sid(service_id, index)
    local ok, codeoe, res = router_mgr:call_target(quanta_id, "rpc_command_execute" , cmd_name, target_id, ...)
    if not ok then
        log_err("[AdminMgr][exec_system_cmd] rpc_command_execute failed! cmd_name=%s", cmd_name)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = res }
end

--service command
function AdminMgr:exec_service_cmd(service_id, cmd_name, ...)
    local ok, codeoe = router_mgr:broadcast(service_id, "rpc_command_execute" , cmd_name, ...)
    if not ok then
        log_err("[AdminMgr][exec_service_cmd] rpc_command_execute failed! cmd_name=%s", cmd_name)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = "success" }
end

--hash command
function AdminMgr:exec_hash_cmd(service_id, cmd_name, target_id, ...)
    local ok, codeoe, res = router_mgr:call_hash(service_id, target_id, "rpc_command_execute", cmd_name, target_id, ...)
    if not ok then
        log_err("[AdminMgr][exec_hash_cmd] rpc_command_execute failed! cmd_name=%s", cmd_name)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = res }
end

--local command
function AdminMgr:exec_local_cmd(service_id, cmd_name, ...)
    event_mgr:notify_trigger(cmd_name, ...)
    return { code = 0, msg = "success" }
end

--兼容在线和离线的玩家指令
function AdminMgr:exec_offline_cmd(service_id, cmd_name, player_id, ...)
    log_debug("[AdminMgr][exec_offline_cmd] cmd_name:%s player_id:%s", cmd_name, player_id)
    local ok, codeoe, res = online:call_lobby(player_id, "rpc_command_execute", cmd_name, player_id, ...)
    if not ok then
        log_err("[AdminMgr][exec_offline_cmd] rpc_command_execute failed! cmd_name=%s player_id=%s", cmd_name, player_id)
        return { code = 1, msg = codeoe }
    end
    if codeoe == PLAYER_NOT_EXIST then
        ok, codeoe, res = router_mgr:call_lobby_hash(player_id, "rpc_command_execute", cmd_name, player_id, ...)
        if not ok then
            log_err("[AdminMgr][exec_offline_cmd] rpc_command_execute failed! player_id:%s, cmd_name=%s", player_id, cmd_name)
            return { code = 1, msg = codeoe }
        end
        return { code = codeoe, msg = res }
    end
    return { code = codeoe, msg = res }
end

--player command
function AdminMgr:exec_player_cmd(service_id, cmd_name, player_id, ...)
    if player_id == 0 then
        local ok, codeoe, res = router_mgr:call_lobby_random("rpc_command_execute", cmd_name, player_id, ...)
        if not ok then
            log_err("[AdminMgr][exec_player_cmd] rpc_command_execute failed! cmd_name=%s player_id=%s", cmd_name, player_id)
            return { code = 1, msg = codeoe }
        end
        return { code = codeoe, msg = res }
    end
    local ok, codeoe, res = online:call_lobby(player_id, "rpc_command_execute", cmd_name, player_id, ...)
    if not ok then
        log_err("[AdminMgr][exec_player_cmd] rpc_command_execute failed! cmd_name=%s player_id=%s", cmd_name, player_id)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = res }
end

quanta.admin_mgr = AdminMgr()

return AdminMgr