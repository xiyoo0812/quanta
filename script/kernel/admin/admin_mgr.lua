--gm_mgr.lua
import("driver/http.lua")
import("kernel/admin/web_mgr.lua")
local ljson         = require("luacjson")
local cmd_parser    = import("utility/cmdline.lua")
local args_parser   = import("utility/cmdlist.lua")

local jdecode       = ljson.decode
local jencode       = ljson.encode
local tunpack       = table.unpack
local tinsert       = table.insert
local sformat       = string.format
local log_info      = logger.info
local log_err       = logger.err
local log_debug     = logger.debug

local KernCode      = enum("KernCode")

local web_mgr       = quanta.web_mgr
local event_mgr     = quanta.event_mgr

local AdminMgr = class()
local prop = property(AdminMgr)
prop:accessor("cmd_args", {})
prop:accessor("cmd_infos", {})
prop:accessor("cmd_services", {})

function AdminMgr:__init()
    ljson.encode_sparse_array(true)
    --监听事件
    event_mgr:add_listener(self, "rpc_report_gm_cmd")
    event_mgr:add_listener(self, "rpc_execute_gm_cmd")
    --注册回调
    web_mgr:register_post("/gm", "on_web_command", self)
    web_mgr:register_post("/message", "on_web_message", self)
end

--执行上报gm给后台
function AdminMgr:report_cmd(cmd_list, service_id)
    if self.cmd_services[service_id] then
        return
    end

    --同服务只执行一次
    local cmd_args = self.cmd_args
    local cmd_infos = self.cmd_infos
    for _, cmd in pairs(cmd_list) do
        if not cmd_infos[cmd.name] then
            cmd_infos[cmd.name] = cmd
            cmd_args[cmd.name] = args_parser(cmd.args)
        end
    end
    local code, res = web_mgr:forward_request("gm_report", "call_post", {}, jencode(cmd_list))
    if code ~= 200 then
        log_err("[AdminMgr][report_cmd] failed!")
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
    local cmd_data = cmd_parser(command)
    if not cmd_data then
        return { code = 1, msg = "command parser failed" }
    end
    local cmd_name = cmd_data.name
    local cmd_info = self.cmd_infos[cmd_name]
    if not cmd_info then
        return { code = 1, msg = "command not exist!" }
    end
    local args_def = self.cmd_args[cmd_name]
    if not args_def then
        return { code = 1, msg = "args define not exist!" }
    end
    local narg_num = #args_def
    local iarg_num = cmd_data.args and #cmd_data.args or 0
    if iarg_num ~= narg_num then
        return { code = 1, msg = sformat("args not match (need %d but get %d)!", narg_num, iarg_num) }
    end
    local cmd_args = { cmd_name }
    for i, arg in ipairs(cmd_data.args or {}) do
        local arg_info = args_def[i]
        if arg_info and arg_info.unpack then
            tinsert(cmd_args, arg_info.unpack(arg))
        else
            tinsert(cmd_args, arg)
        end
    end
    local ok, res = tunpack(event_mgr:notify_listener("rpc_gm_dispatch", cmd_args, cmd_info.gm_type))
    if ok then
        return res
    end
    return { code = 1, msg = res }
end

--后台GM调用
function AdminMgr:exec_web_message(cmd_data)
    local cmd_name = cmd_data.name
    local cmd_info = self.cmd_infos[cmd_name]
    if not cmd_info then
        return { code = 1, msg = "command not exist!" }
    end
    local args_def = self.cmd_args[cmd_name]
    if not args_def then
        return { code = 1, msg = "args define not exist!" }
    end
    local cmd_args = { cmd_name }
    for _, arg_info in ipairs(args_def) do
        local arg = cmd_data[arg_info.name]
        if not arg then
            return { code = 1, msg = sformat("args not match (need %s field)!", arg_info.name) }
        end
        if arg_info.unpack then
            arg = arg_info.unpack(arg)
        end
        tinsert(cmd_args, arg)
    end
    local ok, res = tunpack(event_mgr:notify_listener("rpc_gm_dispatch", cmd_args, cmd_info.gm_type))
    if ok then
        return res
    end
    return { code = 1, msg = res }
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
