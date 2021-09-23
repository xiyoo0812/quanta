--gm_mgr.lua
import("utility/cmdline.lua")
import("kernel/admin/web_mgr.lua")
local ljson         = require("lcjson")

local jdecode       = ljson.decode
local jencode       = ljson.encode
local tunpack       = table.unpack
local env_get       = environ.get
local env_number    = environ.number
local log_info      = logger.info
local log_debug     = logger.debug

local KernCode      = enum("KernCode")

local cmdline       = quanta.get("cmdline")
local web_mgr       = quanta.get("web_mgr")
local event_mgr     = quanta.get("event_mgr")

local AdminMgr = class()
local prop = property(AdminMgr)
prop:accessor("app_id", 0)
prop:accessor("chan_id", 0)
prop:accessor("deploy", "local")
prop:accessor("cmd_services", {})

function AdminMgr:__init()
    ljson.encode_sparse_array(true)
    self.deploy = env_get("QUANTA_DEPLOY")
    self.app_id = env_number("QUANTA_APP_ID")
    self.chan_id = env_number("QUANTA_CHAN_ID")
    --监听事件
    event_mgr:add_listener(self, "rpc_report_gm_cmd")
    event_mgr:add_listener(self, "rpc_execute_gm_cmd")
    --注册回调
    web_mgr:register_post("/gm", "on_web_command", self)
    web_mgr:register_post("/message", "on_web_message", self)
end

--执行上报gm给后台
function AdminMgr:report_cmd(command_list, service_id)
    --同服务只执行一次
    if self.cmd_services[service_id] then
        return
    end
    for _, command in pairs(command_list) do
        cmdline:register_command(command.name, command.args, command.gm_type)
    end
    local web_cmd_argss = {
        app_id   = self.app_id,
        chan_id  = self.chan_id,
        deploy   = self.deploy,
        cmd_list = command_list,
    }
    local code, res = web_mgr:forward_request("gm_report", "call_post", {}, jencode(web_cmd_argss))
    if code ~= 200 then
        --log_err("[AdminMgr][report_cmd] failed!")
        return KernCode.RPC_FAILED, res
    end
    log_info("[AdminMgr][report_cmd] success!")
    self.cmd_services[service_id] = true
    return KernCode.SUCCESS, res
end

--上报gm给后台
function AdminMgr:rpc_report_gm_cmd(cmd_list, service_id)
    return self:report_cmd(cmd_list, service_id)
end

--执行远程gm
function AdminMgr:rpc_execute_gm_cmd(command)
    return self:exec_web_command(command)
end

--后台GM调用
function AdminMgr:exec_web_command(command)
    local result, err = cmdline:parser_command(command)
    if not result then
        return { code = 1, msg = err }
    end
    local ok, res = tunpack(event_mgr:notify_listener("rpc_gm_dispatch", result.args, result.type))
    if not ok then
        return { code = 1, msg = res }
    end
    return res
end

--后台GM调用
function AdminMgr:exec_web_message(cmd_data)
    local result, err = cmdline:parser_command(cmd_data)
    if not result then
        return { code = 1, msg = err }
    end
    local ok, res = tunpack(event_mgr:notify_listener("rpc_gm_dispatch", result.args, result.type))
    if not ok then
        return { code = 1, msg = res }
    end
    return res
end

--后台GM调用
function AdminMgr:on_web_command(body, headers)
    log_debug("[AdminMgr][on_web_command] body：%s", body)
    local cmd_req = jdecode(body)
    return self:exec_web_command(cmd_req.data)
end

--后台接口调用
function AdminMgr:on_web_message(body, headers)
    log_debug("[AdminMgr][on_web_message] body：%s", body)
    local cmd_req = jdecode(body)
    return self:exec_web_message(cmd_req.data)
end

return AdminMgr
