--monitor_agent.lua
local ljson = require("luacjson")
ljson.encode_sparse_array(true)
local cmd_parser    = require("utility.cmdline")
local args_parser   = require("utility.cmdlist")
local DxConnection  = import("share/dx/dx_connection.lua")

local tunpack       = table.unpack
local tjoin         = quanta_extend.join
local json_encode   = ljson.encode
local json_decode   = ljson.decode
local sformat       = string.format
local env_addr      = environ.addr
local env_status    = environ.status
local signal_quit   = signal.quit
local log_err       = logger.err
local log_warn      = logger.warn
local log_info      = logger.info
local tonumber      = math.tointeger
local errcode       = err.Code
local SUCCESS       = errcode.SUCCESS
local serialize     = logger.serialize

local moni_cmd      = ncmd_monitor.NCmdId
local node_cmd      = ncmd_monitor.NodeCmdId
local WEB_FUNC_NAME     = quantaconst.WEB_FUNC_NAME
local WEB_LOG_FUNC_NAME = quantaconst.WEB_LOG_FUNC_NAME

local timer_mgr     = quanta.timer_mgr
local router_mgr    = quanta.router_mgr
local thread_mgr    = quanta.thread_mgr

local RECONNECT_TIME    = 5
local TIMER_PERIOD      = 5000
local REPORT_PERIOD     = 5000
local DELAY_TIME        = 3000

local MonitorAgent = singleton(DxConnection)

function MonitorAgent:__init()
    self.dx_session  = nil
    self.next_connect_time = 0
    self.monitor_ip, self.monitor_port = env_addr("ENV_MONITOR_ADDR")

    self:check_conn()
    timer_mgr:loop(TIMER_PERIOD, function()
        self:update()
    end)

    self.log_feishu = env_status("ENV_FEISHU_STATE")
    --cmd_list
    self.cmd_list = {}
end

function MonitorAgent:build_cmd()
    self.cmd_argds = {}
    for _, cmd in pairs(self.cmd_list) do
        self.cmd_argds[cmd.name] = args_parser(cmd.args)
    end
end

function MonitorAgent:insert_cmd(cmd_list)
    self.cmd_list = tjoin(cmd_list, self.cmd_list)
    self:build_cmd()
end

function MonitorAgent:replace_cmd(cmd_list)
    self.cmd_list = cmd_list
    self:build_cmd()
end

function MonitorAgent:get_cmd_argds()
    return self.cmd_argds or {}
end

function MonitorAgent:report_cmd()
    if #self.cmd_list > 0 then
        local data = {
            id  = quanta.id,
            index = quanta.index,
            group  = quanta.service,
            cmd_list = self.cmd_list
        }
        local ok, code = self:service_request("gm_report", data)
        if ok and errcode.SUCCESS == code then
            log_info("[MonitorAgent][report_cmd] success!")
        else
            timer_mgr:once(REPORT_PERIOD, function()
                self:report_cmd()
            end)
        end
    end
end

function MonitorAgent:check_conn()
    if self.dx_session == nil then
        if quanta.now >= self.next_connect_time then
            self.next_connect_time = quanta.now + RECONNECT_TIME
            self:connect(self.monitor_ip, self.monitor_port)
        end
    end
end

-- 连接成回调
function MonitorAgent:on_connect_impl()
    log_info("[MonitorAgent][on_connect_impl]: connect monitor success!")
    -- 上报数据
    self:report_request("node_status")
    -- 上报gm列表
    self:report_cmd()
end

-- 请求上报飞书
function MonitorAgent:report_feishu(title, body)
    if self.log_feishu then
        self:report_request("log_feishu", {title, body})
    end
end

-- 请求上报
function MonitorAgent:report_request(type, data)
    local req = {
        svr_id = quanta.id,
        svr_name = quanta.name,
        report_type = type,
        json_data = json_encode(data or {}),
    }
    return self:send_dx(moni_cmd.NID_MONITOR_REPORT_REQ, req)
end

-- 请求服务
function MonitorAgent:service_request(service, data)
    local req = {
        svr_id = quanta.id,
        service = service,
        json_data = json_encode(data),
    }
    local ok, res = self:call_dx(moni_cmd.NID_MONITOR_SERVICE_REQ, req)
    if ok then
        return tunpack(json_decode(res.json_data))
    end
    return false
end

-- 数据回调
function MonitorAgent:on_recv(cmd_id, data, session_id)
    if tonumber(data.cmd_id) == node_cmd.CMD_BROADCAST then
        self:on_broadcast(data.json_data)
        return
    end

    if quanta.id ~= data.svr_id then
        log_info("MonitorAgent:on_recv->data.svr_id:%s", data.svr_id)
        return
    end

    if cmd_id == moni_cmd.NID_MONITOR_COMMAND_REQ then
        local child_cmd_id = tonumber(data.cmd_id)
        local response = { code = 1, msg = "not support cmdid" }
        if child_cmd_id == node_cmd.CMD_EXIT then
            response = self:on_exit(data.json_data)
        elseif child_cmd_id == node_cmd.CMD_LOG then
            response = self:on_log(data.json_data)
        elseif child_cmd_id == node_cmd.CMD_SYS then
            response = self:on_sys_cmd(data.json_data)
        elseif child_cmd_id == node_cmd.CMD_GM then
            response = self:on_command(data.json_data)
        end
        local res_data = {
            json_data = json_encode(response),
        }
        self:callback_dx(moni_cmd.NID_MONITOR_COMMAND_RES, res_data, session_id)
    end
end

-- 处理Monitor通知退出消息
function MonitorAgent:on_exit(json_data)
    -- 发个退出通知
    if router_mgr then
        router_mgr:notify_trigger("quanta_frame_exit", json_data)
    end

    -- 关闭会话连接
    thread_mgr:fork(function()
        thread_mgr:sleep(1000)
        self:close()
    end)
    timer_mgr:once(DELAY_TIME, function()
        self:delay_exit()
    end)

    return { code = 0 }
end

-- 延迟退出
function MonitorAgent:delay_exit()
    log_warn("MonitorAgent:delay_exit->svr_name:%s", quanta.name)
    -- 下一逻辑帧退出
    signal_quit()
end

-- 处理Monitor通知退出消息
function MonitorAgent:on_log(json_data)
    json_data = json_decode(json_data)
    local func_name = WEB_LOG_FUNC_NAME[json_data.func_id]
    if not func_name then
        log_err("[MonitorAgent][on_broadcast]->get func name failed! func_id:%s", json_data.func_id)
        return {code = 1, msg="find func failed!"}
    end

    local log_mgr = quanta.online_log_mgr
    return log_mgr[func_name](log_mgr, json_data)
end

function MonitorAgent:on_sys_cmd(json_data)
    local json_obj = json_decode(json_data)
    local call_ret = router_mgr:notify_listener(json_obj.rpc_name, json_obj.data)
    local ok, ec, ret = tunpack(call_ret)
    if not ok or SUCCESS ~= ec then
        log_err("[MonitorAgent][on_sys_cmd] web_rpc faild: ok=%s, ec=%s", serialize(ok), serialize(ec))
        return { code = ok and ec or errcode.RPC_FAILED, msg = ok and "" or ec}
    end

    return { code = 0 , data = ret}
end

function MonitorAgent:on_broadcast(json_data)
    --log_info("on_broadcast->json_data:%s", json_data)
    if router_mgr and json_data then
        json_data = json_decode(json_data)
        local func_name = WEB_FUNC_NAME[json_data.func_id]
        if not func_name then
            log_err("[MonitorAgent][on_broadcast]->get func name failed! func_id:%s", json_data.func_id)
            return
        end
        router_mgr:notify_trigger(json_data.func, json_data)
    end
end

-- 处理Monitor通知执行GM指令
function MonitorAgent:on_command(json_data)
    log_info("[MonitorAgent][on_command]json_data->%s", json_data)
    local cmd_info = cmd_parser(json_data)
    if not router_mgr or not cmd_info then
        return { code = 1, msg = "command not exist" }
    end
    local cmd_name = cmd_info.name
    local cmd_argd = self.cmd_argds[cmd_name]
    if not cmd_argd then
        return { code = 1, msg = "command not exist!" }
    end
    local narg_num = #cmd_argd
    local iarg_num = cmd_info.args and #cmd_info.args or 0
    if iarg_num ~= narg_num then
        return { code = 1, msg = sformat("args not match (need %d but get %d)!", narg_num, iarg_num) }
    end
    local args = {}
    for i, arg in ipairs(cmd_info.args or {}) do
        local arg_info = cmd_argd[i]
        if arg_info and arg_info.unpack then
            args[i] = arg_info.unpack(arg)
        else
            args[i] = arg
        end
    end
    local ok, res = tunpack(router_mgr:notify_listener(cmd_name, tunpack(args)))
    if not ok then
        return {code = 1, msg = res}
    end
    return {code = 0, data = res}
end

-- 连接关闭回调
function MonitorAgent:on_close_impl(err)
    --log_info("[MonitorAgent][on_close_impl]: %s!", err)

    if err == "active-close" then
        -- 主动关闭连接不走重连逻辑
        return
    end

    -- 会话重置
    self.dx_session = nil
    -- 设置重连时间
    self.next_connect_time = quanta.now
end

function MonitorAgent:update()
    --检查连接
    self:check_conn()

    self:send_heartbeat_req()
end

quanta.monitor = MonitorAgent()

return MonitorAgent
