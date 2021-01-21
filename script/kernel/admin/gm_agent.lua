--gm_agent.lua

local tunpack       = table.unpack
local tinsert       = table.insert
local log_info      = logger.info
local check_success = utility.check_success

local PeriodTime    = enum("PeriodTime")

local router_mgr    = quanta.get("router_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local event_mgr     = quanta.get("event_mgr")

local GMAgent = singleton()
local prop = property(GMAgent)
prop:accessor("cmd_list", {})
prop:accessor("report_svr_id", nil)

function GMAgent:__init()
    --注册gm事件分发
    event_mgr:add_listener(self, "rpc_gm_execute")
end

function GMAgent:watch_service(gm_service)
    -- 关注 gm服务 事件
    router_mgr:watch_service_close(self, gm_service)
    router_mgr:watch_service_ready(self, gm_service)
end

function GMAgent:insert_cmd(cmd_list)
    for _, cmd in pairs(cmd_list) do
        self.cmd_list[cmd.name] = cmd
    end
end

function GMAgent:report_cmd()
    if not next(self.cmd_list) then
        return
    end
    local cmd_list = {}
    for _, cmd in pairs(self.cmd_list) do
        tinsert(cmd_list, cmd)
    end
    thread_mgr:success_call(PeriodTime.SECOND_MS, function()
        local ok, code = router_mgr:call_target(self.report_svr_id, "rpc_report_gm_cmd", cmd_list, quanta.service_id)
        if ok and check_success(code) then
            log_info("[GMAgent][report_cmd] success!")
            return true
        end
        return false
    end)
end

-- 通知执行GM指令
function GMAgent:rpc_gm_execute(cmd_name, ...)
    log_info("[GMAgent][rpc_gm_execute]->cmd_name:%s", cmd_name)
    local ok, res = tunpack(event_mgr:notify_listener(cmd_name, ...))
    if not ok then
        return {code = 1, msg = res}
    end
    return res
end

-- 服务器启动准备事件
function GMAgent:on_service_ready(id, service_name)
    log_info("[GMAgent][on_service_ready]->id:%s, service_name:%s", id, service_name)
    self.report_svr_id = id
    -- 上报gm列表
    self:report_cmd()
end

-- 监听服务器关闭事件
function GMAgent:on_service_close(id)
    self.report_svr_id = nil
end

quanta.gm_agent = GMAgent()

return GMAgent
