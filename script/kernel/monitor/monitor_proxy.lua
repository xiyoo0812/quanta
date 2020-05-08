--monitor_proxy.lua
local cmd_parser    = import("utility/cmdline.lua")
local args_parser   = import("utility/cmdlist.lua")
local RpcClient     = import("kernel/network/rpc_client.lua")

local tjoin         = table.join
local tunpack       = table.unpack
local sformat       = string.format
local env_addr      = environ.addr
local signal_quit   = signal.quit
local log_err       = logger.err
local log_warn      = logger.warn
local log_info      = logger.info
local serialize     = logger.serialize
local check_success = utility.check_success
local check_failed  = utility.check_failed

local KernCode      = enum("KernCode")
local NetwkTime     = enum("NetwkTime")

local event_mgr     = quanta.event_mgr
local timer_mgr     = quanta.timer_mgr
local router_mgr    = quanta.router_mgr
local thread_mgr    = quanta.thread_mgr

local TIMER_PERIOD  = 1000

local MonitorProxy = singleton()
local prop = property(MonitorProxy)
prop:accessor("client", nil)
prop:accessor("cmd_list", {})
prop:accessor("cmd_argds", {})
prop:accessor("next_connect_time", 0)
function MonitorProxy:__init()
    --创建连接
    local ip, port = env_addr("QUANTA_MONITOR_ADDR")
    self.client = RpcClient(self, ip, port)
    --心跳定时器
    timer_mgr:loop(NetwkTime.HEARTBEAT_TIME, function()
        self:on_timer()
    end)
    --检查连接
    self:check_conn()
    --注册事件
    event_mgr:add_listener(self, "on_heartbeat")
end

function MonitorProxy:on_heartbeat()
end

function MonitorProxy:on_timer()
    --检查连接
    self:check_conn()
    --心跳
    self.client:check_lost(quanta.now)
end

-- 连接关闭回调
function MonitorProxy:on_socket_error(client, err)
    if err == "active-close" then
        -- 主动关闭连接不走重连逻辑
        return
    end
    -- 设置重连时间
    self.next_connect_time = quanta.now
end

-- 连接成回调
function MonitorProxy:on_socket_connect(client)
    log_info("[MonitorProxy][on_socket_connect]: connect monitor success!")
    -- 到monitor注册
    self.client:send("rpc_monitor_register", quanta.id, quanta.service_id, quanta.index, quanta.name)
    -- 上报gm列表
    self:report_cmd()
end

--检查连接
function MonitorProxy:check_conn()
    if not self.client:is_alive() then
        local now = quanta.now
        if now>= self.next_connect_time then
            self.next_connect_time = now + NetwkTime.RECONNECT_TIME
            self.client:connect()
        end
    end
end

function MonitorProxy:build_cmd()
    self.cmd_argds = {}
    for _, cmd in pairs(self.cmd_list) do
        self.cmd_argds[cmd.name] = args_parser(cmd.args)
    end
end

function MonitorProxy:insert_cmd(cmd_list)
    self.cmd_list = tjoin(cmd_list, self.cmd_list)
    self:build_cmd()
end

function MonitorProxy:replace_cmd(cmd_list)
    self.cmd_list = cmd_list
    self:build_cmd()
end

function MonitorProxy:get_cmd_argds()
    return self.cmd_argds or {}
end

function MonitorProxy:report_cmd()
    if #self.cmd_list > 0 then
        local data = {
            id  = quanta.id,
            index = quanta.index,
            service  = quanta.service_id,
            cmd_list = self.cmd_list
        }
        local ok, code = self.client:call("rpc_monitor_post", "gm_report", data)
        if ok and check_success(code) then
            log_info("[MonitorProxy][report_cmd] success!")
        else
            timer_mgr:once(TIMER_PERIOD, function()
                self:report_cmd()
            end)
        end
    end
end

-- 请求服务
function MonitorProxy:service_request(api_name, data)
    local req = {
        data = data,
        id  = quanta.id,
        index = quanta.index,
        service  = quanta.service_id,
    }
    local ok, res = self.client:call("rpc_monitor_post", api_name, req)
    if ok then
        return tunpack(res)
    end
    return false
end

-- 处理Monitor通知退出消息
function MonitorProxy:rpc_quanta_quit(reason)
    -- 发个退出通知
    if router_mgr then
        router_mgr:notify_trigger("on_quanta_quit", reason)
    end
    -- 关闭会话连接
    thread_mgr:fork(function()
        thread_mgr:sleep(1000)
        self.client:close()
    end)
    timer_mgr:once(1000, function()
        log_warn("[MonitorProxy][rpc_quanta_quit]->service:%s", quanta.name)
        signal_quit()
    end)
    return { code = 0 }
end

--执行远程rpc消息
function MonitorProxy:rpc_remote_message(rpc, ...)
    local ok, code, res = tunpack(router_mgr:notify_listener(rpc, ...))
    if not ok or check_failed(code) then
        log_err("[MonitorProxy][rpc_remote_message] web_rpc faild: ok=%s, ec=%s", serialize(ok), code)
        return { code = ok and code or KernCode.RPC_FAILED, msg = ok and "" or code}
    end
    return { code = 0 , data = res}
end

-- 处理Monitor通知执行GM指令
function MonitorProxy:rpc_remote_command(cmd)
    log_info("[MonitorProxy][rpc_remote_command] cmd : %s", cmd)
    local cmd_info = cmd_parser(cmd)
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

quanta.monitor = MonitorProxy()

return MonitorProxy
