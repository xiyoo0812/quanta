-- online_log_mgr.lua
local OnlineLogAgent= import("share/monitor/online_log_agent.lua")
local next          = next
local otime         = os.time
local log_debug     = logger.debug
local ssplit        = string_ext.split
local serialize     = logger.serialize

local router_mgr    = quanta.router_mgr
local timer_mgr     = quanta.timer_mgr
local listener      = quanta.listener

local TIMER_PERIOD  = 1000
local OVERDUE_TIME  = 10 * 1000

local OnlineLogMgr = singleton()

function OnlineLogMgr:__init()
    self.log_agents = {}
    self.trigge_flag = false
end

function OnlineLogMgr:setup()
    router_mgr:add_listener(self, "query_log")
    router_mgr:add_listener(self, "pull_log")
    router_mgr:add_listener(self, "close_log")

    timer_mgr:loop(TIMER_PERIOD, function()
        self:on_timer_check()
    end)
end

function OnlineLogMgr:find(session)
    if session then
        return self.log_agents[session]
    end
end

function OnlineLogMgr:query_log(json_data)
    log_debug("[OnlineLogMgr][query_log]->json_data:%s", serialize(json_data))
    if not json_data.session then
        return {code=1, msg="param errror!"}
    end

    local agent = self.log_agents[json_data.session]
    if not agent then
        self.log_agents[json_data.session] = OnlineLogAgent(json_data.session)
        agent = self.log_agents[json_data.session]
    end

    if not json_data.context or json_data.context == "" then
        return {code = 1, msg = "filter words empty!"}
    end

    if not self.trigge_flag then
        listener:add_trigger(self, "log_output")
        self.trigge_flag = true
    end

    agent:filter(ssplit(json_data.context, ","))

    return {name = "query_log", code = 0, session = json_data.session}
end

function OnlineLogMgr:pull_log(json_data)
    local agent = self:find(json_data.session)
    if not agent then
        return {name = "pull_log", code = 1, msg = "find agent failed!"}
    end

    return {name = "pull_log", code = 0, session = json_data.session,  logs = agent:pull()}
end

function OnlineLogMgr:close_log(json_data)
    log_debug("[OnlineLogMgr][pull_log]->json_data", serialize(json_data))
    if not json_data.session then
        return {name = "close_log", code = 1, msg = "session id empty!"}
    end

    self:clear_agent(json_data.session)

    return {name = "close_log", code = 0}
end

function OnlineLogMgr:on_timer_check()
    local cur_time = otime()
    local overdue = {}
    for session, agent in pairs(self.log_agents) do
        if cur_time - agent.active_time > OVERDUE_TIME then
            overdue[session] = 1
        end
    end

    for session in pairs(overdue) do
        log_debug("[OnlineLogMgr][on_timer_check]->overdue->session:%s", session)
        self:clear_agent(session)
    end
end

function OnlineLogMgr:log_output(str_log)
    for _, agent in pairs(self.log_agents) do
        agent:add_log(str_log)
    end
end

function OnlineLogMgr:clear_agent(session)
    self.log_agents[session] = nil
    if not next(session.log_agents) then
        listener:remove_trigger(self, "log_output")
        self.trigge_flag = false
    end
end

quanta.online_log_mgr = OnlineLogMgr()

return OnlineLogMgr
