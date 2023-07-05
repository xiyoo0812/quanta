--gm_agent.lua

local tunpack       = table.unpack
local log_info      = logger.info
local qsuccess      = quanta.success

local monitor       = quanta.get("monitor")
local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local LOGIC_FAILED  = quanta.enum("KernCode", "LOGIC_FAILED")

local Listener      = import("basic/listener.lua")

local GMAgent = singleton(Listener)
local prop = property(GMAgent)
prop:accessor("command_list", {})

function GMAgent:__init()
    --注册gm事件分发
    event_mgr:add_listener(self, "rpc_command_execute")
    -- 关注 gm服务 事件
    monitor:watch_service_ready(self, "center")
end

--插入一条command
function GMAgent:insert_command(command_list)
    for _, cmd in pairs(command_list) do
        self.command_list[cmd.name] = cmd
    end
end

--执行一条command
--主要用于服务器内部执行GM指令
--command：字符串格式
function GMAgent:execute_command(command)
    local ok, codeoe, res = router_mgr:call_center_master("rpc_execute_command", command)
    if qsuccess(codeoe, ok) then
        return ok, res
    end
    return false, ok and res or codeoe
end

--执行一条command
--主要用于服务器内部执行GM指令
--message：lua table格式
function GMAgent:execute_message(message)
    local ok, codeoe, res = router_mgr:call_center_master("rpc_execute_message", message)
    if qsuccess(codeoe, ok) then
        return ok, res
    end
    return false, ok and res or codeoe
end

--上报gm
function GMAgent:report_command(id)
    local command_list = {}
    for _, cmd in pairs(self.command_list) do
        command_list[#command_list + 1] = cmd
    end
    local ok, code = router_mgr:call_target(id, "rpc_register_command", command_list, quanta.service)
    if qsuccess(code, ok) then
        log_info("[GMAgent][report_command] success!")
        return true
    end
    return false
end

-- 通知执行GM指令
function GMAgent:rpc_command_execute(cmd_name, ...)
    log_info("[GMAgent][rpc_command_execute]->cmd_name:%s", cmd_name)
    local ok, res = tunpack(self:notify_listener(cmd_name, ...))
    return ok and SUCCESS or LOGIC_FAILED, res
end

-- GM服务已经ready
function GMAgent:on_service_ready(id, service_name)
    log_info("[GMAgent][on_service_ready]->id:%s, service_name:%s", id, service_name)
    -- 上报gm列表
    thread_mgr:success_call(2000, function()
        return self:report_command(id)
    end)
end

quanta.gm_agent = GMAgent()

return GMAgent
